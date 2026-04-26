const fs = require('fs');
const path = require('path');

const source = 'C:/Users/Rie Trg/.gemini/antigravity/brain/9f5ceb91-5b54-4a19-9473-c20e3c3f17dc/logo_transparent_1777117905638.png';
const destination = 'd:/tubes ABP2/ngebut.inFIX/ngebut.in/assets/img/logo.png';

try {
    if (fs.existsSync(source)) {
        fs.copyFileSync(source, destination);
        console.log('Successfully copied transparent logo to assets/img/logo.png');
    } else {
        console.error('Source file not found: ' + source);
    }
} catch (err) {
    console.error('Error copying file: ', err);
}
