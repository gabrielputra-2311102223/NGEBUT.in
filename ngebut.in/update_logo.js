const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? 
            walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

const targetDir = __dirname;

walkDir(targetDir, function(filePath) {
    if (filePath.endsWith('.html')) {
        let content = fs.readFileSync(filePath, 'utf8');
        let originalContent = content;
        
        // Root files
        content = content.replace(/<a href="index\.html" class="logo"[^>]*>[\s\S]*?<\/a>/g, 
            '<a href="index.html" class="logo" style="display: flex; align-items: center; justify-content: center;"><img src="assets/img/logo.png" alt="Ngebut.in" style="height: 45px; object-fit: contain;"></a>');
            
        // Subfolder files
        content = content.replace(/<a href="\.\.\/index\.html" class="logo"[^>]*>[\s\S]*?<\/a>/g, 
            '<a href="../index.html" class="logo" style="display: flex; align-items: center; justify-content: center; margin-bottom: 1rem;"><img src="../assets/img/logo.png" alt="Ngebut.in" style="height: 45px; object-fit: contain;"></a>');
            
        if (content !== originalContent) {
            fs.writeFileSync(filePath, content, 'utf8');
            console.log('Updated: ' + filePath);
        }
    }
});
