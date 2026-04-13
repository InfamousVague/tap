import Foundation

#if DEBUG
enum MockData {
    static let servers: [Server] = [
        Server(
            id: "srv-1",
            name: "prod-api",
            host: "10.0.1.10",
            port: 22,
            user: "deploy",
            status: .up,
            latencyMs: 12,
            commands: [
                Command(id: "cmd-1", serverId: "srv-1", label: "Restart API", command: "sudo systemctl restart api", confirm: true, timeoutSec: 30, sortOrder: 0, pinned: true),
                Command(id: "cmd-2", serverId: "srv-1", label: "View Logs", command: "journalctl -u api --no-pager -n 50", confirm: false, timeoutSec: 15, sortOrder: 1, pinned: true),
                Command(id: "cmd-3", serverId: "srv-1", label: "Check Disk", command: "df -h /", confirm: false, timeoutSec: 10, sortOrder: 2, pinned: false),
                Command(id: "cmd-4", serverId: "srv-1", label: "Deploy Latest", command: "cd /opt/api && git pull && make deploy", confirm: true, timeoutSec: 120, sortOrder: 3, pinned: false),
                Command(id: "cmd-5", serverId: "srv-1", label: "Memory Usage", command: "free -h", confirm: false, timeoutSec: 10, sortOrder: 4, pinned: false),
                Command(id: "cmd-6", serverId: "srv-1", label: "Active Connections", command: "ss -tuln | grep LISTEN", confirm: false, timeoutSec: 10, sortOrder: 5, pinned: false),
            ],
            suites: [
                Suite(id: "suite-1", serverId: "srv-1", label: "Health Check"),
                Suite(id: "suite-2", serverId: "srv-1", label: "Full Deploy"),
            ]
        ),
        Server(
            id: "srv-2",
            name: "prod-db",
            host: "10.0.1.20",
            port: 22,
            user: "root",
            status: .up,
            latencyMs: 8,
            commands: [
                Command(id: "cmd-10", serverId: "srv-2", label: "DB Status", command: "systemctl status postgresql", confirm: false, timeoutSec: 10, sortOrder: 0, pinned: true),
                Command(id: "cmd-11", serverId: "srv-2", label: "Backup Now", command: "pg_dump -U postgres app > /backups/$(date +%s).sql", confirm: true, timeoutSec: 300, sortOrder: 1, pinned: true),
                Command(id: "cmd-12", serverId: "srv-2", label: "Connections", command: "psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'", confirm: false, timeoutSec: 10, sortOrder: 2, pinned: false),
                Command(id: "cmd-13", serverId: "srv-2", label: "Table Sizes", command: "psql -U postgres -c \"SELECT relname, pg_size_pretty(pg_total_relation_size(oid)) FROM pg_class ORDER BY pg_total_relation_size(oid) DESC LIMIT 10;\"", confirm: false, timeoutSec: 15, sortOrder: 3, pinned: false),
            ],
            suites: []
        ),
        Server(
            id: "srv-3",
            name: "staging",
            host: "10.0.2.10",
            port: 22,
            user: "deploy",
            status: .down,
            latencyMs: nil,
            commands: [
                Command(id: "cmd-20", serverId: "srv-3", label: "Start Services", command: "docker compose up -d", confirm: true, timeoutSec: 60, sortOrder: 0, pinned: true),
                Command(id: "cmd-21", serverId: "srv-3", label: "Stop Services", command: "docker compose down", confirm: true, timeoutSec: 30, sortOrder: 1, pinned: false),
                Command(id: "cmd-22", serverId: "srv-3", label: "Container Logs", command: "docker compose logs --tail=100", confirm: false, timeoutSec: 15, sortOrder: 2, pinned: false),
            ],
            suites: []
        ),
        Server(
            id: "srv-4",
            name: "nginx-lb",
            host: "10.0.0.5",
            port: 22,
            user: "root",
            status: .up,
            latencyMs: 3,
            commands: [
                Command(id: "cmd-30", serverId: "srv-4", label: "Reload Nginx", command: "nginx -t && systemctl reload nginx", confirm: true, timeoutSec: 15, sortOrder: 0, pinned: true),
                Command(id: "cmd-31", serverId: "srv-4", label: "Access Log", command: "tail -n 50 /var/log/nginx/access.log", confirm: false, timeoutSec: 10, sortOrder: 1, pinned: false),
                Command(id: "cmd-32", serverId: "srv-4", label: "Error Log", command: "tail -n 50 /var/log/nginx/error.log", confirm: false, timeoutSec: 10, sortOrder: 2, pinned: false),
            ],
            suites: [
                Suite(id: "suite-3", serverId: "srv-4", label: "Cert Renewal"),
            ]
        ),
        Server(
            id: "srv-5",
            name: "monitoring",
            host: "10.0.3.10",
            port: 2222,
            user: "admin",
            status: .unknown,
            latencyMs: nil,
            commands: [
                Command(id: "cmd-40", serverId: "srv-5", label: "Grafana Status", command: "systemctl status grafana-server", confirm: false, timeoutSec: 10, sortOrder: 0, pinned: false),
                Command(id: "cmd-41", serverId: "srv-5", label: "Prometheus Status", command: "systemctl status prometheus", confirm: false, timeoutSec: 10, sortOrder: 1, pinned: false),
            ],
            suites: []
        ),
    ]

    static let execResultSuccess = ExecResult(
        status: "success",
        exitCode: 0,
        stdout: """
        ● api.service - Production API
             Loaded: loaded (/etc/systemd/system/api.service; enabled)
             Active: active (running) since Sat 2026-04-12 10:23:01 UTC; 2s ago
           Main PID: 48291 (node)
              Tasks: 11 (limit: 4915)
             Memory: 142.3M
                CPU: 1.204s
             CGroup: /system.slice/api.service
                     └─48291 node /opt/api/dist/server.js

        Apr 12 10:23:01 prod-api systemd[1]: Started Production API.
        Apr 12 10:23:02 prod-api node[48291]: Server listening on port 3000
        Apr 12 10:23:02 prod-api node[48291]: Connected to database
        Apr 12 10:23:02 prod-api node[48291]: Redis cache connected
        Apr 12 10:23:02 prod-api node[48291]: Ready to accept connections
        """,
        stderr: nil,
        durationMs: 2341
    )

    static let execResultFailure = ExecResult(
        status: "failure",
        exitCode: 1,
        stdout: nil,
        stderr: """
        Error: Connection refused
        Could not connect to database at 10.0.1.20:5432
        Retrying in 5 seconds...
        Error: Connection refused
        Fatal: Maximum retries exceeded
        """,
        durationMs: 15023
    )
}
#endif
