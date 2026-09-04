const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 10000;

let qrCodeData = null;
let clientStatus = 'Servidor iniciado. Preparando WhatsApp...';

function clearAuthFolders() {
    const authFolder = path.join(__dirname, '.wwebjs_auth');
    const cacheFolder = path.join(__dirname, '.wwebjs_cache');
    try {
        if (fs.existsSync(authFolder)) fs.rmSync(authFolder, { recursive: true, force: true });
        if (fs.existsSync(cacheFolder)) fs.rmSync(cacheFolder, { recursive: true, force: true });
    } catch (err) {
        console.error('Error al limpiar caché:', err);
    }
}

// Detección segura de Chromium en la instancia de Docker
let chromePath = process.env.PUPPETEER_EXECUTABLE_PATH;
if (!chromePath && fs.existsSync('/usr/bin/chromium')) {
    chromePath = '/usr/bin/chromium';
} else if (!chromePath && fs.existsSync('/usr/bin/chromium-browser')) {
    chromePath = '/usr/bin/chromium-browser';
}

const puppeteerConfig = {
    headless: true,
    args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage', // Indispensable para evitar crash OOM en Render
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--disable-gpu',
        '--js-flags=--max-old-space-size=256'
    ]
};

if (chromePath) {
    puppeteerConfig.executablePath = chromePath;
}

const client = new Client({
    authStrategy: new LocalAuth(),
    puppeteer: puppeteerConfig
});

client.on('qr', (qr) => {
    console.log('📌 Código QR generado.');
    qrCodeData = qr;
    clientStatus = 'QR_READY';
});

client.on('authenticated', () => {
    console.log('🔐 Dispositivo autenticado.');
    clientStatus = 'AUTHENTICATED';
});

client.on('ready', () => {
    console.log('✅ ¡WhatsApp Web listo!');
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

// Ruta para visualizar el QR de forma estable
app.get('/qr', async (req, res) => {
    if (clientStatus === 'READY') {
        return res.send('<h1 style="color:#2e7d32;text-align:center;margin-top:50px;font-family:sans-serif;">✅ ¡WhatsApp Conectado y Listo!</h1>');
    }
    
    if (!qrCodeData) {
        return res.send(`
            <div style="text-align:center;font-family:sans-serif;margin-top:50px;">
                <h2 style="color:#e65100;">⏳ Estado: ${clientStatus}</h2>
                <p style="color:#666;">Iniciando navegador Chromium en Render... La página se recargará sola.</p>
                <script>setTimeout(() => location.reload(), 4000);</script>
            </div>
        `);
    }

    try {
        const qrImage = await qrcode.toDataURL(qrCodeData);
        res.send(`
            <div style="text-align:center;font-family:sans-serif;margin-top:30px;">
                <h2>Escaneá el código QR con el celular de tu papá</h2>
                <img src="${qrImage}" style="width:280px;height:280px;border:8px solid white;box-shadow:0 4px 10px rgba(0,0,0,0.2);border-radius:10px;"/>
                <p>Estado actual: <b>${clientStatus}</b></p>
                <script>setTimeout(() => location.reload(), 7000);</script>
            </div>
        `);
    } catch (err) {
        res.status(500).send('Error generando la imagen QR');
    }
});

app.get('/ping', (req, res) => res.send('Servidor Activo 🚀'));

app.get('/reset', (req, res) => {
    clearAuthFolders();
    res.send('<h2>🔄 Sesión reiniciada. Volvé a abrir <a href="/qr">/qr</a> en 30 segundos.</h2>');
    setTimeout(() => process.exit(0), 1000);
});

app.post('/enviar', async (req, res) => {
    try {
        if (clientStatus !== 'READY') {
            return res.status(503).json({ error: 'WhatsApp no está conectado todavía.' });
        }
        const { cliente, numero, maquina, precio } = req.body;
        if (!numero) return res.status(400).json({ error: 'Falta el número de teléfono' });

        let numLimpio = String(numero).replace(/\D/g, '');
        if (numLimpio.length === 10 && !numLimpio.startsWith('54')) {
            numLimpio = '549' + numLimpio;
        }
        const chatId = `${numLimpio}@c.us`;
        const mensaje = `Hola ${cliente || ''}, ¡tu ${maquina || 'máquina'} ya está reparada y probada! El costo final es de $${precio || 0}. Te esperamos en el taller!`;

        await client.sendMessage(chatId, mensaje);
        res.json({ status: 'OK', mensaje: 'Mensaje enviado' });
    } catch (error) {
        res.status(500).json({ error: error.toString() });
    }
});

// Iniciar Express inmediatamente para responder a las peticiones HTTP
app.listen(PORT, () => {
    console.log(`🚀 Servidor Express activo en puerto ${PORT}`);
    clientStatus = 'Iniciando navegador Chromium...';
    
    // Inicializar el cliente de WhatsApp sin bloquear el hilo web
    client.initialize().catch(err => {
        console.error('❌ Error al inicializar cliente de WhatsApp:', err);
        clientStatus = 'Error al iniciar. Entrá a /reset para reintentar.';
    });
});