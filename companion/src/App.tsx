import React, { useEffect, useState } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { ThemeProvider, Toaster } from '@mattssoftware/base-rn';
import { StatusBar } from 'expo-status-bar';
import { api } from './services/api';
import { TabNavigator } from './navigation/TabNavigator';

export default function App() {
  const [ready, setReady] = useState(false);
  const [configured, setConfigured] = useState(false);

  useEffect(() => {
    async function init() {
      const isConfigured = await api.initialize();
      setConfigured(isConfigured);
      setReady(true);
    }
    init();
  }, []);

  if (!ready) return null;

  return (
    <ThemeProvider defaultMode="system">
      <Toaster>
        <NavigationContainer>
          <StatusBar style="auto" />
          <TabNavigator />
        </NavigationContainer>
      </Toaster>
    </ThemeProvider>
  );
}
