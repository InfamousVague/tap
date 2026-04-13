import { Tabs } from 'expo-router';
import { ThemeProvider, Toaster, useTheme, Icon, icons, Spinner, VStack, Text } from '@mattssoftware/base-rn';
import { amber } from '@mattssoftware/base-rn/src/tokens/colors';
import { StatusBar } from 'expo-status-bar';
import React from 'react';
import { View } from 'react-native';
import { AuthContext, useAuthProvider } from '../src/hooks/useAuth';
import { SignInScreen } from '../src/screens/SignInScreen';

function TabLayout() {
  const { colors } = useTheme();

  return (
    <>
      <StatusBar style="auto" />
      <Tabs
        screenOptions={{
          tabBarStyle: { backgroundColor: colors.bg, borderTopColor: colors.border },
          tabBarActiveTintColor: amber[500],
          tabBarInactiveTintColor: colors.textMuted,
          headerStyle: { backgroundColor: colors.bg, borderBottomColor: colors.border },
          headerTintColor: colors.text,
          headerTitleStyle: { fontWeight: '600' },
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: 'Home',
            tabBarIcon: ({ color }) => <Icon svg={icons.home} size={22} color={color} />,
          }}
        />
        <Tabs.Screen
          name="servers"
          options={{
            title: 'Servers',
            tabBarIcon: ({ color }) => <Icon svg={icons.server} size={22} color={color} />,
          }}
        />
        <Tabs.Screen
          name="history"
          options={{
            title: 'History',
            tabBarIcon: ({ color }) => <Icon svg={icons.clock} size={22} color={color} />,
          }}
        />
        <Tabs.Screen
          name="keys"
          options={{
            title: 'Keys',
            tabBarIcon: ({ color }) => <Icon svg={icons.key} size={22} color={color} />,
          }}
        />
        <Tabs.Screen
          name="settings"
          options={{
            title: 'Settings',
            tabBarIcon: ({ color }) => <Icon svg={icons.settings} size={22} color={color} />,
          }}
        />
      </Tabs>
    </>
  );
}

function AuthGate() {
  const auth = useAuthProvider();
  const { colors } = useTheme();

  if (!auth.isReady) {
    return (
      <View style={{ flex: 1, backgroundColor: colors.bg, justifyContent: 'center', alignItems: 'center' }}>
        <VStack gap={3} align="center">
          <Icon svg={icons.terminal} size={48} color={amber[500]} />
          <Spinner size="lg" />
        </VStack>
      </View>
    );
  }

  return (
    <AuthContext.Provider value={auth}>
      {auth.isAuthenticated ? <TabLayout /> : <SignInScreen />}
    </AuthContext.Provider>
  );
}

export default function RootLayout() {
  return (
    <ThemeProvider defaultMode="system">
      <Toaster>
        <AuthGate />
      </Toaster>
    </ThemeProvider>
  );
}
