const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(express.json());

// Permitir peticiones desde la app Flutter (CORS)
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});

const PORT = process.env.PORT || 10000;

let qrCodeData = null;
let clientStatus = 'Iniciando servidor...';

function clearAuthFolders() {
    const authFolder = path.join(__dirname, '.wwebjs_auth');
    const cacheFolder = path.join(__dirname, '.wwebjs_cache');
    try {
        if (fs.existsSync(authFolder)) fs.rmSync(authFolder, { recursive: true, force: true });
        if (fs.existsSync(cacheFolder)) fs.rmSync(cacheFolder, { recursive: true, force: true });
    } catch (err) {
        console.error('Error al limpiar sesión:', err);
    }
}

// Configuración original para compatibilidad total de escaneo
const client = new Client({
    authStrategy: new LocalAuth(),
    webVersionCache: {
        type: 'remote',
        remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
    },
    puppeteer: {
        headless: true,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--single-process',
            '--disable-gpu',
            '--disable-extensions',
            '--disable-component-update',
            '--js-flags="--max-old-space-size=256"'
        ]
    }
});

client.on('qr', (qr) => {
    console.log('📌 ¡Código QR generado!');
    qrCodeData = qr;
    clientStatus = 'QR_READY';
});

client.on('authenticated', () => {
    console.log('🔐 Dispositivo autenticado.');
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

app.get('/qr', async (req, res) => {
    if (clientStatus === 'READY' || clientStatus === 'AUTHENTICATED') {
        return res.send(`
            <div style="text-align:center;font-family:sans-serif;margin-top:50px;">
                <h1 style="color:#2e7d32;">✅ ¡WhatsApp Conectado y Activo!</h1>
                <p style="color:#555;">Estado actual: <b>${clientStatus}</b>. El servicio está listo para enviar notificaciones.</p>
            </div>
        `);
    }

    if (!qrCodeData) {
        return res.send(`
            <div style="text-align:center;font-family:sans-serif;margin-top:50px;">
                <h2 style="color:#e65100;">⏳ Estado: ${clientStatus}</h2>
                <p style="color:#666;">Cargando navegador... La página se actualizará sola.</p>
                <script>setTimeout(() => location.reload(), 4000);</script>
            </div>
        `);
    }

    try {
        const qrImage = await qrcode.toDataURL(qrCodeData);
        res.send(`
            <div style="text-align:center;font-family:sans-serif;margin-top:30px;">
                <h2>Escaneá el código QR con tu celular</h2>
                <img src="${qrImage}" style="width:280px;height:280px;border:8px solid white;box-shadow:0 4px 10px rgba(0,0,0,0.2);border-radius:10px;"/>
                <p>Estado: <b>${clientStatus}</b></p>
                <script>setTimeout(() => location.reload(), 5000);</script>
            </div>
        `);
    } catch (err) {
        res.status(500).send('Error al generar la imagen QR');
    }
});

app.get('/ping', (req, res) => res.send('Servidor Activo 🚀'));

app.get('/reset', (req, res) => {
    clearAuthFolders();
    res.send('<h2>🔄 Sesión eliminada. Redirigiendo a /qr...</h2><script>setTimeout(()=>window.location.href="/qr", 3000)</script>');
    setTimeout(() => process.exit(0), 1000);
});

app.post('/enviar', async (req, res) => {
    try {
        // CORRECCIÓN: Permite enviar si está en READY o en AUTHENTICATED
        if (clientStatus !== 'READY' && clientStatus !== 'AUTHENTICATED') {
            return res.status(503).json({ error: `WhatsApp no está listo. Estado actual: ${clientStatus}` });
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

app.listen(PORT, () => {
    console.log(`🚀 Servidor Express iniciado en el puerto ${PORT}`);
    clientStatus = 'Iniciando navegador...';
    
    client.initialize().catch(err => {
        console.error('❌ Error al inicializar cliente de WhatsApp:', err);
        clientStatus = 'Error al iniciar. Podés intentar recargar o /reset';
    });
});