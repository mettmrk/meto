const fs = require('fs');
const filePath = 'c:\\Users\\toopt\\Desktop\\meto\\lib\\screens\\voice_room_screen.dart';
let content = fs.readFileSync(filePath, 'utf8');

// Fix the multi-line withValues
content = content.replace(/\.withValues\(\s*alpha:\s*([0-9.]+),\s*\)/g, '.withOpacity($1)');
// Fix the other multi-line withValues (without comma)
content = content.replace(/\.withValues\(\s*alpha:\s*([0-9.]+)\s*\)/g, '.withOpacity($1)');

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed file.');
