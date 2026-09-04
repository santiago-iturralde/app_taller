const { Client, LocalAuth } = require('whatsapp-web.js');
const express = require('express');
const fs = require('fs');
const path = require('path');
const app = express();

app.use(express.json());

let latestQR = null;
let status = 'Iniciando cliente de WhatsApp en Render...';

process.on('unhandledRejection', (reason) => {
    console.error('⚠️ Advertencia:', reason);
});

const client = new Client({
    authStrategy: new LocalAuth(),
    takeoverOnConflict: true,
    takeoverTimeoutMs: 0,
    puppeteer: {
        executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || '/usr/bin/chromium',
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--disable-gpu',
            '--disable-extensions',
            '--disable-software-rasterizer',
            '--mute-audio'
        ]
    }
});

client.on('qr', (qr) => {
    latestQR = qr;
    status = 'QR listo para escanear';
    console.log('📱 Nuevo QR generado. Ver en: /qr');
});

client.on('authenticated', () => {
    latestQR = null;
    status = 'Autenticado. Vinculando con el teléfono...';
    console.log('🔑 Autenticado correctamente.');
});

client.on('ready', () => {
    latestQR = null;
    status = 'Conectado';
    console.log('✅ ¡WhatsApp Conectado y listo en la nube!');
});

client.on('auth_failure', (msg) => {
    status = 'Error de autenticación. Intentá reiniciar desde /reset';
    console.error('❌ Error de autenticación:', msg);
});

client.on('disconnected', (reason) => {
    latestQR = null;
    status = 'Desconectado';
    console.log('❌ Dispositivo desconectado:', reason);
});

// Vista principal para escanear el QR
app.get('/qr', (req, res) => {
    if (status === 'Conectado') {
        return res.send(`
            <html>
                <body style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0;font-family:sans-serif;background-color:#e8f5e9;">
                    <h1 style="color:#2e7d32;">✅ ¡WhatsApp Conectado Exitosamente!</h1>
                    <p style="color:#444;font-size:18px;">El servidor en la nube ya está listo para enviar mensajes automáticamente.</p>
                </body>
            </html>
        `);
    }

    if (!latestQR) {
        return res.send(`
            <html>
                <head><meta http-equiv="refresh" content="5"></head>
                <body style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0;font-family:sans-serif;background-color:#fff3e0;">
                    <h2 style="color:#e65100;">⏳ ${status}</h2>
                    <p style="color:#666;">La página se actualizará automáticamente cada 5 segundos...</p>
                </body>
            </html>
        `);
    }

    const qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=350x350&data=${encodeURIComponent(latestQR)}`;
    res.send(`
        <html>
            <body style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0;font-family:sans-serif;background-color:#f4f4f9;">
                <h2 style="color:#333;">Escaneá este QR con el celular de tu papá:</h2>
                <img src="${qrImageUrl}" alt="QR Code" style="border:12px solid white;box-shadow:0 4px 15px rgba(0,0,0,0.15);border-radius:12px;"/>
                <p style="color:#888;margin-top:15px;">Si se traba o querés reiniciar el intento, entrá a <a href="/reset">/reset</a></p>
            </body>
        </html>
    `);
});

// Ruta de rescate para borrar sesiones incompletas y reiniciar
app.get('/reset', (req, res) => {
    try {
        const authPath = path.join(__dirname, '.wwebjs_auth');
        if (fs.existsSync(authPath)) {
            fs.rmSync(authPath, { recursive: true, force: true });
        }
        res.send('<h2>🔄 Sesión limpiada. Reiniciando servidor... Volvé a entrar a <a href="/qr">/qr</a> en 30 segundos.</h2>');
        setTimeout(() => process.exit(0), 1000); // Render reiniciará el contenedor automáticamente
    } catch (error) {
        res.send('Error al reiniciar: ' + error.toString());
    }
});

app.get('/ping', (req, res) => {
    res.send('Servidor Activo 🚀');
});

app.post('/enviar', async (req, res) => {
    try {
        const { cliente, numero, maquina, precio } = req.body;

        if (!numero) {
            return res.status(400).json({ error: 'Falta el número de teléfono' });
        }

        let numLimpio = String(numero).replace(/\D/g, '');
        if (numLimpio.length === 10 && !numLimpio.startsWith('54')) {
            numLimpio = '549' + numLimpio;
        }
        const chatId = `${numLimpio}@c.us`;

        const mensaje = `Hola ${cliente || ''}, ¡tu ${maquina || 'máquina'} ya está reparada y probada! El costo final es de $${precio || 0}. Te esperamos en el taller!`;

        console.log(`📩 Enviando a ${chatId}...`);
        await client.sendMessage(chatId, mensaje);
        console.log('🚀 Enviado correctamente');

        res.json({ status: 'OK', mensaje: 'Mensaje enviado' });
    } catch (error) {
        console.error('❌ Error al enviar:', error);
        res.status(500).json({ error: error.toString() });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
    client.initialize().catch(err => {
        console.error('❌ Error Client:', err);
    });
});