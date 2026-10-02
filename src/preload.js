const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktopApi', {
  isDesktop: true,
  platform: process.platform,
  print: (options) => ipcRenderer.invoke('print-content', options),
  getPrinters: () => ipcRenderer.invoke('get-printers'),
  getVersion: () => ipcRenderer.invoke('get-app-version'),
});
