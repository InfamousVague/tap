import React from 'react';
import { ScrollView, RefreshControl, Alert } from 'react-native';
import {
  useTheme, VStack, HStack, Text, Card, ListItem, Separator, Badge, Icon, icons, Skeleton, Button, useToast,
} from '@mattssoftware/base-rn';
import { amber } from '@mattssoftware/base-rn/src/tokens/colors';
import { api } from '../services/api';
import { useQuery } from '../hooks/useApi';
import { useAuth } from '../hooks/useAuth';

export function SettingsScreen() {
  const { colors, spacing } = useTheme();
  const { data: health, loading, error, refetch } = useQuery(() => api.healthCheck(), []);
  const { signOut } = useAuth();
  const { toast } = useToast();

  // Show toast on fetch error
  React.useEffect(() => {
    if (error) toast({ type: 'error', title: 'Failed to connect to relay', message: error });
  }, [error]);

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4] }}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={refetch} tintColor={amber[500]} />}
    >
      <VStack gap={6}>
        {/* Relay Connection */}
        <VStack gap={2}>
          <Text variant="label" color={colors.textMuted}>Relay</Text>
          <Card variant="outline" padding="none">
            <ListItem
              title="Status"
              trailing={
                loading ? <Skeleton width={60} height={20} /> : (
                  <Badge size="sm" color={health ? 'success' : 'error'} variant="subtle">
                    <Text variant="caption">{health ? 'Connected' : 'Offline'}</Text>
                  </Badge>
                )
              }
            />
            <Separator />
            <ListItem
              title="Version"
              trailing={
                <Text variant="caption" color={colors.textMuted} mono>
                  {health?.version ?? '-'}
                </Text>
              }
            />
            <Separator />
            <ListItem
              title="Endpoint"
              trailing={
                <Text variant="caption" color={colors.textMuted} mono>
                  tap.mattssoftware.com
                </Text>
              }
            />
          </Card>
        </VStack>

        {/* App Info */}
        <VStack gap={2}>
          <Text variant="label" color={colors.textMuted}>About</Text>
          <Card variant="outline" padding="none">
            <ListItem
              title="App Version"
              trailing={<Text variant="caption" color={colors.textMuted} mono>0.1.0</Text>}
            />
            <Separator />
            <ListItem
              title="Developer"
              trailing={
                <HStack gap={1} align="center">
                  <Icon svg={icons.code} size={14} color={amber[500]} />
                  <Text variant="caption" color={colors.textMuted}>MattsSoftware</Text>
                </HStack>
              }
            />
          </Card>
        </VStack>

        {/* Account */}
        <VStack gap={2}>
          <Text variant="label" color={colors.textMuted}>Account</Text>
          <Button
            variant="secondary"
            intent="error"
            size="sm"
            style={{ borderWidth: 0 }}
            onPress={signOut}
          >
            Sign Out
          </Button>
        </VStack>

        {/* Danger Zone */}
        <VStack gap={2}>
          <Text variant="label" color={colors.textMuted}>Danger Zone</Text>
          <Button
            variant="secondary"
            intent="error"
            size="sm"
            style={{ borderWidth: 0 }}
            onPress={() => {
                Alert.alert(
                  'Delete Account',
                  'Are you sure? This will permanently delete your account and all data.',
                  [
                    { text: 'Cancel', style: 'cancel' },
                    {
                      text: 'Delete',
                      style: 'destructive',
                      onPress: async () => {
                        try {
                          await api.deleteAccount();
                          signOut();
                        } catch (e: any) {
                          toast({ type: 'error', title: 'Failed to delete account', message: e.message ?? 'Please try again.' });
                        }
                      },
                    },
                  ],
                );
              }}
          >
            Delete Account
          </Button>
        </VStack>
      </VStack>
    </ScrollView>
  );
}
