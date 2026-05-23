use a2::{
    Client, ClientConfig, Endpoint,
    request::notification::{
        DefaultNotificationBuilder, NotificationBuilder, NotificationOptions, Priority,
    },
};
use std::sync::Arc;

pub struct ApnsClient {
    client: Client,
    topic: String,
}

impl ApnsClient {
    /// Create from a .p8 key file (token-based auth)
    pub fn new(key_path: &str, key_id: &str, team_id: &str, topic: &str, production: bool) -> anyhow::Result<Self> {
        let mut key_file = std::fs::File::open(key_path)?;
        let endpoint = if production {
            Endpoint::Production
        } else {
            Endpoint::Sandbox
        };
        let config = ClientConfig::new(endpoint);
        let client = Client::token(&mut key_file, key_id, team_id, config)
            .map_err(|e| anyhow::anyhow!("Failed to create APNs client: {}", e))?;
        Ok(Self {
            client,
            topic: topic.to_string(),
        })
    }

    /// Try to create from RelayConfig. Returns None if APNs is not configured.
    pub fn from_config(config: &crate::config::NotificationsConfig) -> Option<Arc<Self>> {
        if !config.apns_enabled {
            return None;
        }

        let key_path = config.apns_key_path.as_deref()?;
        let key_id = config.apns_key_id.as_deref()?;
        let team_id = config.apns_team_id.as_deref()?;

        // Default topic is the main app bundle ID
        let topic = "com.mattssoftware.tap";

        match Self::new(key_path, key_id, team_id, topic, true) {
            Ok(client) => {
                tracing::info!("APNs client initialized (key_id={})", key_id);
                Some(Arc::new(client))
            }
            Err(e) => {
                tracing::error!("Failed to initialize APNs client: {}", e);
                None
            }
        }
    }

    pub async fn send_server_down_alert(&self, device_token: &str, server_name: &str) -> anyhow::Result<()> {
        let body = format!("{} is unreachable", server_name);
        let builder = DefaultNotificationBuilder::new()
            .set_title("Server Down")
            .set_body(&body)
            .set_sound("default");

        let options = NotificationOptions {
            apns_topic: Some(&self.topic),
            apns_priority: Some(Priority::High),
            ..Default::default()
        };

        let payload = builder.build(device_token, options);
        self.client.send(payload).await
            .map_err(|e| anyhow::anyhow!("APNs send failed: {}", e))?;
        Ok(())
    }

    pub async fn send_server_up_alert(&self, device_token: &str, server_name: &str) -> anyhow::Result<()> {
        let body = format!("{} is back online", server_name);
        let builder = DefaultNotificationBuilder::new()
            .set_title("Server Recovered")
            .set_body(&body)
            .set_sound("default");

        let options = NotificationOptions {
            apns_topic: Some(&self.topic),
            ..Default::default()
        };

        let payload = builder.build(device_token, options);
        self.client.send(payload).await
            .map_err(|e| anyhow::anyhow!("APNs send failed: {}", e))?;
        Ok(())
    }
}
