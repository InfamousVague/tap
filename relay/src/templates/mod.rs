use once_cell::sync::Lazy;
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct Template {
    pub id: String,
    pub category: String,
    pub label: String,
    pub command: String,
    pub confirm: bool,
    pub timeout_sec: u32,
    pub variables: Vec<String>,
}

pub static TEMPLATES: Lazy<Vec<Template>> = Lazy::new(|| {
    vec![
        // System
        t("sys-disk", "System", "Check disk usage", "df -h / | tail -1", false, 10, vec![]),
        t("sys-memory", "System", "Check memory", "free -h | head -2", false, 10, vec![]),
        t("sys-cpu", "System", "Check CPU load", "uptime", false, 10, vec![]),
        t("sys-procs", "System", "Top processes (by memory)", "ps aux --sort=-%mem | head -20", false, 10, vec![]),
        t("sys-uptime", "System", "Check uptime", "uptime -p", false, 10, vec![]),

        // Systemd
        t("svc-restart", "Systemd", "Restart service", "systemctl restart {{service}}", true, 30, vec!["service"]),
        t("svc-stop", "Systemd", "Stop service", "systemctl stop {{service}}", true, 30, vec!["service"]),
        t("svc-status", "Systemd", "Service status", "systemctl status {{service}} --no-pager", false, 10, vec!["service"]),
        t("svc-logs", "Systemd", "View service logs", "journalctl -u {{service}} -n 30 --no-pager", false, 10, vec!["service"]),

        // Docker
        t("docker-ps", "Docker", "List containers", "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'", false, 10, vec![]),
        t("docker-restart", "Docker", "Restart container", "docker restart {{container}}", true, 30, vec!["container"]),
        t("docker-logs", "Docker", "Container logs", "docker logs --tail 30 {{container}}", false, 10, vec!["container"]),
        t("docker-stats", "Docker", "Docker stats", "docker stats --no-stream --format 'table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}'", false, 15, vec![]),

        // Nginx
        t("nginx-test", "Nginx", "Test config", "nginx -t", false, 10, vec![]),
        t("nginx-reload", "Nginx", "Reload Nginx", "systemctl reload nginx", true, 15, vec![]),
        t("nginx-access", "Nginx", "Access log (last 20)", "tail -20 /var/log/nginx/access.log", false, 10, vec![]),
        t("nginx-error", "Nginx", "Error log (last 20)", "tail -20 /var/log/nginx/error.log", false, 10, vec![]),

        // Database
        t("pg-ready", "Database", "PostgreSQL status", "pg_isready", false, 10, vec![]),
        t("redis-ping", "Database", "Redis ping", "redis-cli ping", false, 10, vec![]),
        t("mysql-status", "Database", "MySQL status", "mysqladmin status", false, 10, vec![]),

        // Git/Deploy
        t("git-pull", "Deploy", "Git pull", "cd {{path}} && git pull", true, 60, vec!["path"]),
        t("git-commit", "Deploy", "Current commit", "cd {{path}} && git log --oneline -1", false, 10, vec!["path"]),
        t("pm2-restart", "Deploy", "PM2 restart", "pm2 restart {{app}}", true, 30, vec!["app"]),
        t("pm2-status", "Deploy", "PM2 status", "pm2 status", false, 10, vec![]),

        // Network
        t("net-port", "Network", "Check port", "ss -tlnp | grep {{port}}", false, 10, vec!["port"]),
        t("net-connections", "Network", "Connection count", "ss -s", false, 10, vec![]),
        t("net-dns", "Network", "DNS lookup", "dig {{domain}} +short", false, 10, vec!["domain"]),
    ]
});

fn t(id: &str, category: &str, label: &str, command: &str, confirm: bool, timeout_sec: u32, variables: Vec<&str>) -> Template {
    Template {
        id: id.to_string(),
        category: category.to_string(),
        label: label.to_string(),
        command: command.to_string(),
        confirm,
        timeout_sec,
        variables: variables.into_iter().map(|s| s.to_string()).collect(),
    }
}
