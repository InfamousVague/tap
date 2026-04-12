import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useTheme, Icon, icons } from '@mattssoftware/base-rn';
import { HomeScreen } from '../screens/HomeScreen';
import { ServersScreen, ServerDetailScreen } from '../screens/ServersScreen';
import { HistoryScreen } from '../screens/HistoryScreen';
import { KeysScreen } from '../screens/KeysScreen';
import { SettingsScreen } from '../screens/SettingsScreen';
import { ExecuteScreen } from '../screens/ExecuteScreen';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

function ServersStack() {
  const { colors } = useTheme();
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: colors.bg },
        headerTintColor: colors.text,
      }}
    >
      <Stack.Screen name="ServersList" component={ServersScreen} options={{ headerShown: false }} />
      <Stack.Screen name="ServerDetail" component={ServerDetailScreen} options={({ route }: any) => ({ title: route.params.serverName })} />
      <Stack.Screen name="Execute" component={ExecuteScreen} options={{ title: 'Execute' }} />
    </Stack.Navigator>
  );
}

export function TabNavigator() {
  const { colors } = useTheme();

  return (
    <Tab.Navigator
      screenOptions={{
        tabBarStyle: { backgroundColor: colors.bg, borderTopColor: colors.border },
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.textMuted,
        headerStyle: { backgroundColor: colors.bg },
        headerTintColor: colors.text,
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{
          tabBarIcon: ({ color }) => <Icon svg={icons.home} size={22} color={color} />,
        }}
      />
      <Tab.Screen
        name="Servers"
        component={ServersStack}
        options={{
          headerShown: false,
          tabBarIcon: ({ color }) => <Icon svg={icons.server} size={22} color={color} />,
        }}
      />
      <Tab.Screen
        name="History"
        component={HistoryScreen}
        options={{
          tabBarIcon: ({ color }) => <Icon svg={icons.clock} size={22} color={color} />,
        }}
      />
      <Tab.Screen
        name="Keys"
        component={KeysScreen}
        options={{
          title: 'SSH Keys',
          tabBarIcon: ({ color }) => <Icon svg={icons.key} size={22} color={color} />,
        }}
      />
      <Tab.Screen
        name="Settings"
        component={SettingsScreen}
        options={{
          tabBarIcon: ({ color }) => <Icon svg={icons.settings} size={22} color={color} />,
        }}
      />
    </Tab.Navigator>
  );
}
