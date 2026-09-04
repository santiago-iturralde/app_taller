const express = require('express');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

let qrCodeData = null;
let clientStatus = 'DISCONNECTED';

// Función para limpiar archivos de sesión corruptos si el intento anterior falló
function clearAuthFolders() {
    const authFolder = path.join(__dirname, '.wwebjs_auth');
    const cacheFolder = path.join(__dirname, '.wwebjs_cache');
    try {
        if (fs.existsSync(authFolder)) {
            fs.rmSync(authFolder, { recursive: true, force: true });
            console.log('🧹 Limpiada la carpeta .wwebjs_auth corrupta');
        }
        if (fs.existsSync(cacheFolder)) {
            fs.rmSync(cacheFolder, { recursive: true, force: true });
            console.log('🧹 Limpiada la carpeta .wwebjs_cache corrupta');
        }
    } catch (err) {
        console.error('Error al limpiar carpetas:', err);
    }
}

// Configuración de WhatsApp Client optimizada para Render
const client = new Client({
    authStrategy: new LocalAuth(),
    webVersionCache: {
        type: 'remote',
        remotePath: 'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.3000.1014588042-alpha.html',
    },
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
            '--disable-gpu',
            '--single-process', // Ahorro crítico de RAM en Render
            // Simula un navegador Chrome real en Windows para evitar que WhatsApp bloquee la vinculación
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
    clearAuthFolders(); // Limpia archivos si falló
});

client.on('disconnected', (reason) => {
    console.log('⚠️ Cliente desconectado:', reason);
    clientStatus = 'DISCONNECTED';
    clearAuthFolders();
});

client.initialize();

// Ruta para visualizar el QR desde la web
app.get('/qr', async (req, res) => {
    if (clientStatus === 'READY') {
        return res.send('<h2 style="font-family: sans-serif; color: green; text-align: center; margin-top: 50px;">✅ WhatsApp ya está vinculado y funcionando correctamente.</h2>');
    }
    if (!qrCodeData) {
        return res.send('<h2 style="font-family: sans-serif; text-align: center; margin-top: 50px;">⏳ Generando código QR... Actualiza la página en 5 segundos.</h2>');
    }
    try {
        const qrImage = await qrcode.toDataURL(qrCodeData);
        res.send(`
            <div style="text-align: center; font-family: sans-serif; margin-top: 40px;">
                <h1>Escanea el código QR con WhatsApp</h1>
                <img src="${qrImage}" style="width: 280px; height: 280px; border: 1px solid #ccc; padding: 10px; border-radius: 8px;"/>
                <p>Estado del servidor: <b>${clientStatus}</b></p>
                <p style="color: #666; font-size: 14px;">La página se actualiza automáticamente cada 8 segundos.</p>
                <script>
                    setTimeout(() => location.reload(), 8000);
                </script>
            </div>
        `);
    } catch (err) {
        res.status(500).send('Error generando el código QR');
    }
});

app.get('/', (req, res) => {
    res.send(`Servidor activo. Estado de WhatsApp: ${clientStatus}`);
});

app.listen(PORT, () => {
    console.log(`Servidor iniciado en el puerto ${PORT}`);
});