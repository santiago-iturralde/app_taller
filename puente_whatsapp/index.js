const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

let qrCodeData = null;
let clientStatus = 'DISCONNECTED';

function clearAuthFolders() {
    const authFolder = path.join(__dirname, '.wwebjs_auth');
    const cacheFolder = path.join(__dirname, '.wwebjs_cache');
    try {
        if (fs.existsSync(authFolder)) {
            fs.rmSync(authFolder, { recursive: true, force: true });
        }
        if (fs.existsSync(cacheFolder)) {
            fs.rmSync(cacheFolder, { recursive: true, force: true });
        }
    } catch (err) {
        console.error('Error al limpiar carpetas de sesión:', err);
    }
}

const client = new Client({
    authStrategy: new LocalAuth(),
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
            '--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36'
        ]
    }
});

client.on('qr', (qr) => {
    console.log('📌 Nuevo código QR generado.');
    qrCodeData = qr;
    clientStatus = 'QR_READY';
});

client.on('authenticated', () => {
    console.log('🔐 Dispositivo autenticado con éxito.');
    clientStatus = 'AUTHENTICATED';
});

client.on('ready', () => {
    console.log('✅ ¡WhatsApp Web está completamente listo y conectado!');
    clientStatus = 'READY';
    qrCodeData = null;
});

client.on('auth_failure', (msg) => {
    console.error('❌ Fallo de autenticación:', msg);
    clientStatus = 'AUTH_FAILURE';
    clearAuthFolders();
});

client.on('disconnected', (reason) => {
    console.log('⚠️ Cliente desconectado:', reason);
    clientStatus = 'DISCONNECTED';
    clearAuthFolders();
});

// Ruta visual para escanear el QR en HD
app.get('/qr', async (req, res) => {
    if (clientStatus === 'READY') {
        return res.send(`
            <div style="text-align: center; font-family: sans-serif; margin-top: 50px;">
                <h1 style="color: #2e7d32;">✅ ¡WhatsApp Conectado Exitosamente!</h1>
                <p style="color: #444; font-size: 18px;">El sistema ya está listo para enviar notificaciones automáticas desde la app.</p>
            </div>
        `);
    }
    if (!qrCodeData) {
        return res.send(`
            <div style="text-align: center; font-family: sans-serif; margin-top: 50px;">
                <h2 style="color: #e65100;">⏳ Inicializando navegador y generando código QR...</h2>
                <p style="color: #666;">La página se actualizará automáticamente en unos segundos.</p>
                <script>setTimeout(() => location.reload(), 5000);</script>
            </div>
        `);
    }
    try {
        const qrImage = await qrcode.toDataURL(qrCodeData);
        res.send(`
            <div style="text-align: center; font-family: sans-serif; margin-top: 40px;">
                <h2>Escaneá el código QR con el celular de tu papá</h2>
                <img src="${qrImage}" style="width: 300px; height: 300px; border: 12px solid white; box-shadow: 0 4px 15px rgba(0,0,0,0.15); border-radius: 12px;"/>
                <p style="color: #666; font-size: 14px; margin-top: 15px;">Estado: <b>${clientStatus}</b></p>
                <script>setTimeout(() => location.reload(), 7000);</script>
            </div>
        `);
    } catch (err) {
        res.status(500).send('Error al generar la imagen del código QR');
    }
});

// Ruta de rescate para borrar sesiones trabadas
app.get('/reset', (req, res) => {
    clearAuthFolders();
    res.send('<h2>🔄 Sesión eliminada. Reiniciando el servicio... Volvé a entrar a <a href="/qr">/qr</a> en 30 segundos.</h2>');
    setTimeout(() => process.exit(0), 1000);
});

// Endpoint de keep-alive para UptimeRobot
app.get('/ping', (req, res) => {
    res.send('Servidor Activo 🚀');
});

// Endpoint principal utilizado por la app de Flutter
app.post('/enviar', async (req, res) => {
    try {
        if (clientStatus !== 'READY') {
            return res.status(503).json({ error: 'WhatsApp no está conectado aún.' });
        }

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

        console.log(`📩 Enviando mensaje a ${chatId}...`);
        await client.sendMessage(chatId, mensaje);
        console.log('🚀 Mensaje enviado correctamente');

        res.json({ status: 'OK', mensaje: 'Mensaje enviado' });
    } catch (error) {
        console.error('❌ Error al enviar:', error);
        res.status(500).json({ error: error.toString() });
    }
});

client.initialize().catch(err => console.error('❌ Error Client Init:', err));

app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});