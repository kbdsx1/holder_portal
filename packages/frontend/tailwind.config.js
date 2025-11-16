import path from 'path';

export default {
  content: [
    path.join(__dirname, 'index.html'),
    path.join(__dirname, 'src/**/*.{js,jsx}')
  ],
  theme: {
    extend: {
      colors: {
        primary: '#1B4332',
        accent: '#95D5B2'
      }
    }
  },
  plugins: []
};
