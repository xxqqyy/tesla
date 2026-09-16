const path = require('node:path')

// This repository keeps uni-app files at the project root instead of src/.
process.env.UNI_INPUT_DIR = path.resolve(__dirname, '..')
require('@dcloudio/vite-plugin-uni/bin/uni.js')
