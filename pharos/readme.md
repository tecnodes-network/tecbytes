# Pharos Sync Monitor

## Installation & Setup

1. **Make the script executable:**
   ```bash
   chmod +x pharos-sync.sh
   ```

2. **Install required dependencies (if not already installed):**
   ```bash
   # For Debian/Ubuntu systems:
   sudo apt-get install bc jq curl

   # For CentOS/RHEL systems:
   sudo yum install bc jq curl
   ```

## Usage

Run the script manually:
```bash
./pharos-sync.sh
```

Or set up automated monitoring with cron:
```bash
# Edit crontab
crontab -e

# Add line to run every 5 minutes:
*/5 * * * * /path/to/pharos-sync.sh >> /var/log/sync_monitor.log 2>&1

# Or run every minute for more frequent monitoring:
* * * * * /path/to/pharos-sync.sh >> /var/log/sync_monitor.log 2>&1
```

## Features

✅ **Persistent State**: Remembers last run time and block number
✅ **Sync Rate Calculation**: Shows blocks per second and per minute
✅ **ETA Estimation**: Predicts when sync will complete
✅ **Readable Output**: Clean formatting with time breakdowns
✅ **Error Handling**: Manages first run and edge cases

## Data Storage

The script stores its state in `/tmp/sync_monitor.dat` containing:
- Timestamp of last run
- Block number at last run  
- Sync status (syncing/synced)

## Example Output

```
=== Pharos Sync Monitor ===
Current time: Thu Sep 25 14:43:22 CEST 2025

🔄 Node is syncing...
Current block: 12345678
Highest block: 12346000
Blocks remaining: 322

📊 Sync Statistics (since last run):
Time elapsed: 0h 5m 0s
Blocks synced: 150
Avg blocks per second: 0.5000
Avg blocks per minute: 30.00

⏱️  Estimated completion:
Time remaining: 0d 0h 10m 44s
Estimated completion: Thu Sep 25 14:54:06 CEST 2025

Data stored in: /tmp/sync_monitor.dat
```

## Troubleshooting

- Ensure your RPC endpoint is accessible at 127.0.0.1:18100
- Check that jq, bc, and curl are installed
- Verify write permissions for /tmp/sync_monitor.dat
- For custom RPC endpoint, modify the RPC variable in the script
