import path from 'path';

export default {
  content: [
    path.join(__dirname, 'index.html'),
    path.join(__dirname, 'src/**/*.{js,jsx}')
  ],
  theme: {
    extend: {
      colors: {
        primary: '#000000',
        accent: '#FFD700'
      }
    }
  },
  plugins: []
};
