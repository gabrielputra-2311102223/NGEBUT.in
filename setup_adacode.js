const { spawn } = require('child_process');

const child = spawn('npx.cmd', ['adacode', 'setup', 'claude'], {
  stdio: ['pipe', 'pipe', 'pipe'],
  shell: true
});

child.stdout.on('data', (data) => {
  const output = data.toString();
  console.log(output);
  
  if (output.includes('Select the language')) {
    child.stdin.write('\r\n');
  } else if (output.includes('Run npm install')) {
    child.stdin.write('y\r\n');
  } else if (output.includes('API Key')) {
    child.stdin.write('sk-adacode-c02aa43c3c96e90c9a98747eb0f8024e18f01cda8e520151\r\n');
  }
});

child.stderr.on('data', (data) => {
  console.error(data.toString());
});

child.on('close', (code) => {
  console.log(`Child process exited with code ${code}`);
});
