const { Client, LocalAuth } = require('whatsapp-web.js');
const express = require('express');
const qrcode = require('qrcode-terminal');
const app = express();

app.use(express.json());

// Evitar que el servidor se apague ante fallos de conexión de Puppeteer
process.on('unhandledRejection', (reason) => {
    console.error('⚠️ Advertencia (Unhandled Rejection capturado):', reason);
});

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
            '--disable-gpu'
        ]
    }
});

client.on('qr', (qr) => {
    console.log('--------------------------------------------------');
    console.log('📱 ESCANEA ESTE CÓDIGO QR CON WHATSAPP:');
    qrcode.generate(qr, { small: true });
    console.log('--------------------------------------------------');
});

client.on('ready', () => {
    console.log('✅ ¡WhatsApp Conectado y listo en la nube!');
});

client.on('auth_failure', (msg) => {
    console.error('❌ Error de autenticación:', msg);
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

console.log('🔄 Inicializando cliente de WhatsApp...');
client.initialize().catch(err => {
    console.error('❌ Error al inicializar WhatsApp Client:', err);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});