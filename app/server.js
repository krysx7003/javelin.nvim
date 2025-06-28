const express = require('express');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');
const sharp = require('sharp');
const app = express();
const port = 8081; 

const clients = new Map();
let filePath;
let fileExt;
let isImage;
let isPDF;

function openBrowser() {
    const url = `http://localhost:${port}`;
    console.log(`Opening Firefox window to ${url}`);
    
    exec(`firefox ${url}`, (error) => {
        if (error) {
            console.error('Failed to open Firefox:', error);
            console.log('Make sure Firefox is installed and in your PATH');
        }
    });
}

async function getImageSize() {
    if (!isImage) return null;
    try {
        const metadata = await sharp(filePath).metadata();
        return {
            width: metadata.width,
            height: metadata.height
        };
    } catch (err) {
        console.error('Error getting image dimensions:', err);
        return null;
    }
}

app.get('/', async (req, res) => {
    const dimensions = isImage ? await getImageSize() : null;
    const filename = path.basename(filePath);
    const extension = path.extname(filePath).toUpperCase().replace('.', '');
    const clientId = Date.now();
    
    let title = `${filename} (${extension} ${isImage ? 'Image' : 'Document'}`;
    
    if (dimensions) {
        title += `, ${dimensions.width} × ${dimensions.height} pixels)`;
    } else {
        title += ')';
    }

    if (isPDF) {
        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, height=device-height">
                <title>${title}</title>
                <style>
                    body {
                        margin: 0;
                        height: 100vh;
                        overflow: hidden;
                    }
                    embed {
                        width: 100%;
                        height: 100%;
                        border: none;
                    }
                </style>
                <script>
                    const eventSource = new EventSource('/events?clientId=${clientId}');
                    eventSource.onmessage = (e) => {
                        if (e.data === 'close') {
                            window.close();
                        }
                    };
                </script>
            </head>
            <body>
                <embed src="/file" type="application/pdf">
            </body>
            </html>
        `);
    } else {
        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, height=device-height;">
                <link rel="stylesheet" href="resource://content-accessible/ImageDocument.css">
                <link rel="stylesheet" href="resource://content-accessible/TopLevelImageDocument.css">
                <script>
                    const eventSource = new EventSource('/events?clientId=${clientId}');
                    eventSource.onmessage = (e) => {
                        if (e.data === 'close') {
                            window.close();
                        }
                    };
                    
                    let isZoomed = false;
                    function toggleZoom() {
                        const img = document.querySelector('img');
                        const container = document.querySelector('.container');
                        
                        if (!isZoomed) {
                            originalWidth = img.offsetWidth;
                            originalHeight = img.offsetHeight;
                            img.style.maxWidth = 'none';
                            img.style.maxHeight = 'none';
                            img.style.width = (originalHeight * 2) + 'px';
                            img.style.height = (originalHeight * 2) + 'px';
                            img.style.position = 'static';
                            img.style.top = '0';
                            img.style.left = '0';
                            container.style.overflow = 'scroll';
                            img.style.cursor = 'zoom-out';
                            container.style.position = 'absolute';
                            container.style.top = '0';
                            container.style.left = '0';
                            container.style.right = '0';
                            container.style.bottom = '0';
                        } else {
                            img.style.maxWidth = '100%';
                            img.style.maxHeight = '100%';
                            img.style.width = 'auto';
                            img.style.height = 'auto';
                            img.style.position = 'absolute';

                            container.style.overflow = 'hidden';
                            img.style.cursor = 'zoom-in';
                            container.style.position = '';
                            container.style.top = '';
                            container.style.left = '';
                        }
                        isZoomed = !isZoomed;
                    }
                </script>
                <title>${title}</title>
                <style>
                    body {
                        margin: 0;
                        height: 100vh;
                        overflow: hidden;
                        position: relative;
                    }
                    .image-container {
                        width: 100%;
                        height: 100%;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        overflow: hidden;
                    }
                    img {
                        max-width: 100%;
                        max-height: 100%;
                        object-fit: contain;
                        cursor: zoom-in;
                        transition: transform 0.25s ease;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <img src="/file" alt="${filename}" onclick="toggleZoom()">
                </div>
            </body>
            </html>
        `);
    }
});

app.get('/file', (req, res) => {
    res.sendFile(filePath);
});

app.get('/events', (req, res) => {
    const clientId = req.query.clientId;
    console.log(`Client connected: ${clientId}`);
    
    res.setHeader('Content-Type', 'text/event-stream');
    clients.set(clientId, res);
    
    req.on('close', () => {
        console.log(`Client disconnected: ${clientId}`);
        clients.delete(clientId);
    });
});

app.post('/new-tab/*filePath', (req, res) => {
    filePath = req.params.filePath;
    if (Array.isArray(filePath)) {
        filePath = filePath.join('/');
    }
    filePath = '/'+filePath;
    console.log(filePath);

    if (!filePath) {
        console.log(`Path: ${filePath} is incorect`)
        res.status(400).send('Missing file path');
        return;
    }

    fileExt = path.extname(filePath).toLowerCase();
    isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(fileExt);
    isPDF = fileExt === '.pdf';

    console.log(`Serving image: ${filePath}`);
    openBrowser();
})

app.post('/close-tab', (req, res) => {
    console.log('Closing Firefox window...');
    clients.forEach((clientRes, id) => {
        clientRes.write('data: close\n\n');
    });
})

function shutdown(){
    console.log('\nClosing Firefox window...');
    clients.forEach((res, id) => {
        res.write('data: close\n\n');
    });
    setTimeout(() => process.exit(0), 300);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});
