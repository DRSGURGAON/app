import React from 'react';
import { createRoot } from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import './styles.css';
import { App } from './App';
import { ToastProvider } from './ui';
createRoot(document.getElementById('root')!).render(<React.StrictMode><HashRouter><ToastProvider><App /></ToastProvider></HashRouter></React.StrictMode>);
