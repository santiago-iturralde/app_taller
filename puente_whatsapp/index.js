const { Client, LocalAuth } = require('whatsapp-web.js');
const express = require('express');
const app = express();

app.use(express.json());

let latestQR = null;

process.on('unhandledRejection', (reason) => {
    console.error('⚠️ Advertencia:', reason);
});

const client = new Client({
    authStrategy: new LocalAuth(),
    // Forzar version cacheada liviana para no saturar la memoria RAM
    webVersionCache: {
        type: 'remote',
        remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
    },
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
            '--js-flags="--max-old-space-size=256"' // Limita la RAM usada por Chromium
        ]
    }
});

client.on('qr', (qr) => {
    latestQR = qr;
    console.log('📱 Nuevo QR generado optimizado. Ver en: /qr');
});

client.on('ready', () => {
    latestQR = null;
    console.log('✅ ¡WhatsApp Conectado y listo en la nube!');
});

app.get('/qr', (req, res) => {
    if (!latestQR) {
        return res.send('<h2 style="font-family:sans-serif;text-align:center;margin-top:50px;color:#2e7d32;">✅ WhatsApp ya está conectado (o inicializando). Recargá en unos segundos.</h2>');
    }
    const qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=350x350&data=${encodeURIComponent(latestQR)}`;
    res.send(`
        <html>
            <body style="display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0;font-family:sans-serif;background-color:#f4f4f9;">
                <h2 style="color:#333;">Escaneá este QR con el celular de tu papá:</h2>
                <img src="${qrImageUrl}" alt="QR Code" style="border:12px solid white;box-shadow:0 4px 15px rgba(0,0,0,0.15);border-radius:12px;"/>
                <p style="color:#666;margin-top:15px;">Si expira, actualizá la página.</p>
            </body>
        </html>
    `);
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

client.initialize().catch(err => console.error('❌ Error Client:', err));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});