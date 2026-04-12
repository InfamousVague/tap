import React, { useState } from 'react';
import { ScrollView, Alert } from 'react-native';
import {
  useTheme,
  VStack,
  HStack,
  Text,
  Card,
  ListItem,
  Separator,
  Toggle,
  Button,
  Badge,
  icons,
  Icon,
} from '@mattssoftware/base-rn';
import { api } from '../services/api';
import { useQuery } from '../hooks/useApi';

export function SettingsScreen({ navigation }: any) {
  const { colors, spacing } = useTheme();
  const { data: health } = useQuery(() => api.healthCheck());
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);

  const disconnect = () => {
    Alert.alert(
      'Disconnect Relay',
      'This will remove your relay connection. You can reconnect later.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Disconnect',
          style: 'destructive',
          onPress: async () => {
            await api.disconnect();
            // TODO: navigate to setup
          },
        },
      ]
    );
  };

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4], gap: spacing[6] }}
    >
      <Text variant="heading">Settings</Text>

      {/* Relay Connection */}
      <VStack gap={2}>
        <Text variant="label" color={colors.textSubtle}>Relay</Text>
        <Card variant="outline" padding="none">
          <ListItem
            title="Connection"
            trailing={
              <Badge color={health ? 'success' : 'error'} size="sm">
                {health ? 'Connected' : 'Offline'}
              </Badge>
            }
            chevron={false}
          />
          <Separator />
          <ListItem
            title="Version"
            trailing={<Text variant="caption" color={colors.textSubtle}>{health?.version ?? '—'}</Text>}
            chevron={false}
          />
          <Separator />
          <ListItem
            title="Generate Watch QR"
            subtitle="Pair your Apple Watch"
            leading={<Icon svg={icons.qrCode} size={18} color={colors.accent} />}
            onPress={() => navigation.navigate('WatchSetup')}
          />
        </Card>
      </VStack>

      {/* Notifications */}
      <VStack gap={2}>
        <Text variant="label" color={colors.textSubtle}>Notifications</Text>
        <Card variant="outline" padding="none">
          <ListItem
            title="Server Alerts"
            subtitle="Get notified when servers go down"
            trailing={
              <Toggle value={notificationsEnabled} onValueChange={setNotificationsEnabled} size="sm" />
            }
            chevron={false}
          />
        </Card>
      </VStack>

      {/* Tokens */}
      <VStack gap={2}>
        <Text variant="label" color={colors.textSubtle}>Security</Text>
        <Card variant="outline" padding="none">
          <ListItem
            title="API Tokens"
            subtitle="Manage device tokens"
            leading={<Icon svg={icons.shield} size={18} color={colors.accent} />}
            onPress={() => navigation.navigate('Tokens')}
          />
          <Separator />
          <ListItem
            title="Two-Factor (TOTP)"
            subtitle="Optional extra security"
            leading={<Icon svg={icons.key} size={18} color={colors.accent} />}
            onPress={() => {}}
          />
        </Card>
      </VStack>

      {/* Danger zone */}
      <VStack gap={2}>
        <Button variant="ghost" intent="error" onPress={disconnect}>
          Disconnect Relay
        </Button>
      </VStack>

      {/* About */}
      <VStack align="center" gap={1}>
        <Text variant="caption" color={colors.textMuted}>Tap v0.1.0</Text>
        <Text variant="caption" color={colors.textMuted}>MattsSoftware · MIT License</Text>
      </VStack>
    </ScrollView>
  );
}
