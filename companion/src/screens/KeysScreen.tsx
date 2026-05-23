import React, { useState } from 'react';
import { ScrollView, RefreshControl, Alert } from 'react-native';
import {
  useTheme, VStack, HStack, Text, Card, Button, Dialog, Input,
  Badge, Icon, icons, Skeleton, useToast,
} from '@mattssoftware/base-rn';
import { amber } from '@mattssoftware/base-rn/src/tokens/colors';
import { useQuery } from '../hooks/useApi';
import { api, SshKeyMeta } from '../services/api';
import * as Haptics from 'expo-haptics';
import * as Clipboard from 'expo-clipboard';

export function KeysScreen() {
  const { colors, spacing } = useTheme();
  const { data: keys, loading, error, refetch } = useQuery(() => api.listKeys(), []);
  const [showGenerate, setShowGenerate] = useState(false);
  const [newKeyLabel, setNewKeyLabel] = useState('');
  const [generating, setGenerating] = useState(false);
  const [generatedKey, setGeneratedKey] = useState<string | null>(null);
  const { toast } = useToast();

  // Show toast on fetch error
  React.useEffect(() => {
    if (error) toast({ type: 'error', title: 'Failed to load keys', message: error });
  }, [error]);

  const generateKey = async () => {
    if (!newKeyLabel.trim()) return;
    try {
      setGenerating(true);
      const result = await api.generateKey(newKeyLabel.trim());
      setGeneratedKey(result.public_key);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      toast({ type: 'success', title: `Key "${newKeyLabel}" generated` });
      refetch();
    } catch (e: any) {
      toast({ type: 'error', title: 'Failed to generate key', message: e.message });
    } finally {
      setGenerating(false);
    }
  };

  const copyKey = async (publicKey: string) => {
    await Clipboard.setStringAsync(publicKey);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    toast({ type: 'success', title: 'Public key copied' });
  };

  const deleteKey = (key: SshKeyMeta) => {
    Alert.alert('Delete Key', `Remove "${key.label}"? Servers using this key will lose SSH access.`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete', style: 'destructive', onPress: async () => {
          try {
            await api.deleteKey(key.id);
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
            toast({ type: 'success', title: `Key "${key.label}" deleted` });
            refetch();
          } catch (e: any) {
            toast({ type: 'error', title: 'Failed to delete key', message: e.message });
          }
        },
      },
    ]);
  };

  const closeDialog = () => {
    setShowGenerate(false);
    setGeneratedKey(null);
    setNewKeyLabel('');
  };

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4] }}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={refetch} tintColor={amber[500]} />}
    >
      <VStack gap={4}>
        <HStack justify="space-between" align="center">
          <Text variant="label" color={colors.textMuted}>
            {keys?.length ?? 0} keys
          </Text>
          <Button variant="primary" size="sm" onPress={() => setShowGenerate(true)}
            icon={<Icon svg={icons.plus} size={14} color="#fff" />}
          >
            Generate
          </Button>
        </HStack>

        {loading && !keys ? (
          <VStack gap={2}><Skeleton height={72} /><Skeleton height={72} /></VStack>
        ) : error && !keys ? (
          <Card variant="outline" padding="lg">
            <VStack align="center" gap={2}>
              <Icon svg={icons.alertTriangle} size={32} color={colors.error} />
              <Text variant="body" color={colors.error} align="center">Failed to load keys</Text>
              <Text variant="caption" color={colors.textMuted} align="center">
                Pull down to retry.
              </Text>
            </VStack>
          </Card>
        ) : keys?.length === 0 ? (
          <Card variant="outline" padding="lg">
            <VStack align="center" gap={3}>
              <Icon svg={icons.key} size={40} color={colors.textMuted} />
              <Text variant="body" color={colors.textMuted} align="center">No SSH keys yet</Text>
              <Text variant="caption" color={colors.textMuted} align="center">
                Generate a key to enable SSH access to your servers.
              </Text>
            </VStack>
          </Card>
        ) : (
          <VStack gap={2}>
            {keys?.map(key => (
              <Card key={key.id} variant="outline" padding="md">
                <VStack gap={2}>
                  <HStack justify="space-between" align="center">
                    <HStack gap={2} align="center">
                      <Icon svg={icons.key} size={16} color={amber[500]} />
                      <Text variant="title">{key.label}</Text>
                    </HStack>
                    <Badge size="sm" color="neutral" variant="subtle">
                      <Text variant="caption" mono>{key.key_type}</Text>
                    </Badge>
                  </HStack>

                  <HStack style={{ backgroundColor: colors.bgMuted, borderRadius: 8, paddingHorizontal: 12, paddingVertical: 8 }}>
                    <Text variant="caption" color={colors.textMuted} mono numberOfLines={1}>
                      {key.public_key}
                    </Text>
                  </HStack>

                  <HStack gap={2}>
                    <Button variant="secondary" size="sm" style={{ backgroundColor: colors.bgMuted, borderWidth: 0 }} onPress={() => copyKey(key.public_key)}
                      icon={<Icon svg={icons.copy} size={14} color={colors.textMuted} />}
                    >
                      Copy
                    </Button>
                    <Button variant="secondary" intent="error" size="sm" style={{ borderWidth: 0 }} onPress={() => deleteKey(key)}
                      icon={<Icon svg={icons.trash} size={14} color={colors.error} />}
                    >
                      Delete
                    </Button>
                  </HStack>
                </VStack>
              </Card>
            ))}
          </VStack>
        )}
      </VStack>

      {/* Generate Key Dialog */}
      <Dialog visible={showGenerate} onClose={closeDialog} title={generatedKey ? 'Key Generated' : 'Generate SSH Key'}>
        <VStack gap={3}>
          {generatedKey ? (
            <>
              <Text variant="body" color={colors.textMuted}>
                Copy this public key to your server's authorized_keys file.
              </Text>
              <Card variant="filled" padding="md">
                <Text variant="caption" mono>{generatedKey}</Text>
              </Card>
              <Button variant="primary" onPress={() => { copyKey(generatedKey); closeDialog(); }}>
                <HStack gap={1} align="center">
                  <Icon svg={icons.copy} size={16} color="white" />
                  <Text variant="label" color="white">Copy & Done</Text>
                </HStack>
              </Button>
            </>
          ) : (
            <>
              <Input
                label="Label"
                placeholder="e.g. prod-deploy"
                value={newKeyLabel}
                onChangeText={setNewKeyLabel}
              />
              <Text variant="caption" color={colors.textMuted}>
                Creates a new Ed25519 keypair on the relay.
              </Text>
              <Button
                variant="primary"
                onPress={generateKey}
                loading={generating}
                disabled={!newKeyLabel.trim()}
              >
                <Text variant="label" color="white">Generate Key</Text>
              </Button>
            </>
          )}
        </VStack>
      </Dialog>
    </ScrollView>
  );
}
