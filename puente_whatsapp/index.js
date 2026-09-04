const { Client, LocalAuth } = require('whatsapp-web.js');
const express = require('express');
const app = express();

app.use(express.json());

const client = new Client({
    authStrategy: new LocalAuth(),
    puppeteer: {
        executablePath: process.env.PUPPETEER_EXECUTABLE_PATH || null,
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
    // Genera el QR en formato texto/ASCII en los logs de la nube
    const qrcode = require('qrcode-terminal');
    qrcode.generate(qr, { small: true });
    console.log('📱 Escaneá el código QR anterior con WhatsApp.');
});

client.on('ready', () => {
    console.log('✅ ¡WhatsApp Conectado y listo en la nube!');
});

// Ruta especial de PING para que UptimeRobot mantenga el servidor despierto 24/7
app.get('/ping', (req, res) => {
    res.send('Servidor Activo 🚀');
});

// Ruta para enviar alerta
app.post('/enviar', async (req, res) => {
    try {
        const { cliente, numero, maquina, precio } = req.body;

        if (!numero) {
            return res.status(400).json({ error: 'Falta el número de teléfono' });
        }

        // Formatear número para Argentina (549 + 10 dígitos)
        let numLimpio = String(numero).replace(/\D/g, '');
        if (numLimpio.length === 10 && !numLimpio.startsWith('54')) {
            numLimpio = '549' + numLimpio;
        }
        const chatId = `${numLimpio}@c.us`;

        // Armar el mensaje directamente acá
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

client.initialize();

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en puerto ${PORT}`);
});