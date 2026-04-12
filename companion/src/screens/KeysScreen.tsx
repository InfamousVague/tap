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
  Button,
  Dialog,
  Input,
  Badge,
  icons,
  Icon,
} from '@mattssoftware/base-rn';
import { useQuery, useMutation } from '../hooks/useApi';
import { api, SshKeyMeta } from '../services/api';
import * as Haptics from 'expo-haptics';

export function KeysScreen() {
  const { colors, spacing } = useTheme();
  const { data: keys, loading, refetch } = useQuery(() => api.listKeys());
  const [showGenerate, setShowGenerate] = useState(false);
  const [newKeyLabel, setNewKeyLabel] = useState('');
  const [generatedKey, setGeneratedKey] = useState<string | null>(null);

  const generateKey = async () => {
    if (!newKeyLabel.trim()) return;
    try {
      const result = await api.generateKey(newKeyLabel);
      setGeneratedKey(result.public_key);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      refetch();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    }
  };

  const deleteKey = async (id: string, label: string) => {
    Alert.alert(
      'Delete Key',
      `Are you sure you want to delete "${label}"? Servers using this key will lose SSH access.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await api.deleteKey(id);
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
            refetch();
          },
        },
      ]
    );
  };

  return (
    <ScrollView
      style={{ flex: 1, backgroundColor: colors.bg }}
      contentContainerStyle={{ padding: spacing[4], gap: spacing[4] }}
    >
      <HStack justify="space-between" align="center">
        <Text variant="heading">SSH Keys</Text>
        <Button
          variant="primary"
          size="sm"
          icon={<Icon svg={icons.plus} size={16} color="#000" />}
          onPress={() => setShowGenerate(true)}
        >
          Generate
        </Button>
      </HStack>

      <Card variant="outline" padding="none">
        {keys?.map((key, i) => (
          <React.Fragment key={key.id}>
            <ListItem
              title={key.label}
              subtitle={`${key.key_type} · ${key.public_key.substring(0, 40)}...`}
              leading={<Icon svg={icons.key} size={18} color={colors.accent} />}
              trailing={<Badge color="neutral" size="sm">{key.key_type}</Badge>}
              onPress={() => deleteKey(key.id, key.label)}
            />
            {i < (keys?.length ?? 0) - 1 && <Separator />}
          </React.Fragment>
        ))}
        {keys?.length === 0 && (
          <VStack align="center" padding={6} gap={2}>
            <Icon svg={icons.key} size={32} color={colors.textMuted} />
            <Text variant="body" color={colors.textSubtle}>No SSH keys yet.</Text>
          </VStack>
        )}
      </Card>

      {/* Generate Dialog */}
      <Dialog
        visible={showGenerate}
        onClose={() => { setShowGenerate(false); setGeneratedKey(null); setNewKeyLabel(''); }}
        title={generatedKey ? 'Key Generated' : 'Generate SSH Key'}
        description={generatedKey ? 'Copy the public key to your server.' : 'Creates a new Ed25519 keypair on the relay.'}
        actions={
          generatedKey ? (
            <Button variant="primary" onPress={() => { setShowGenerate(false); setGeneratedKey(null); setNewKeyLabel(''); }}>
              Done
            </Button>
          ) : (
            <>
              <Button variant="ghost" onPress={() => setShowGenerate(false)}>Cancel</Button>
              <Button variant="primary" onPress={generateKey} disabled={!newKeyLabel.trim()}>Generate</Button>
            </>
          )
        }
      >
        {generatedKey ? (
          <Card variant="filled" padding="sm">
            <Text variant="caption" mono>{generatedKey}</Text>
          </Card>
        ) : (
          <Input
            placeholder="Key label (e.g. prod-deploy)"
            value={newKeyLabel}
            onChangeText={setNewKeyLabel}
          />
        )}
      </Dialog>
    </ScrollView>
  );
}
