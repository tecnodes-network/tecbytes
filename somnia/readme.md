# 🚀 Somnia Monitoring Tool

## 🔧 Configuration Options

### Node Type Support
```bash
NODE_TYPE="validator"    # For validator nodes - monitors validator status + block sync
NODE_TYPE="fullnode"     # For full nodes - monitors block sync only
```

### External RPC Comparison
```bash
EXTERNAL_RPC_CHECK="yes"                                    # Enable/disable external RPC comparison
EXTERNAL_RPCS="https://api.infra.mainnet.somnia.network"    # Comma-separated RPC URLs  
BLOCK_LAG_THRESHOLD=120                                     # Blocks behind before WARNING alert
RPC_TIMEOUT=10                                              # Timeout for RPC calls (seconds)
MIN_SUCCESSFUL_RPCS=1                                       # Minimum successful RPC responses needed
```

## 🎯 Smart Monitoring Features

### **1. Multiple RPC Support**
- ✅ **Comma-separated format**: Support multiple RPCs like `"rpc1,rpc2,rpc3"`
- ✅ **Highest block method**: Uses highest block number from successful RPCs
- ✅ **Automatic failover**: Continues monitoring if some RPCs fail
- ✅ **Load balancing**: Distributes requests across available endpoints

### **2. Intelligent Block Comparison**
- ✅ **EVM compatibility**: Automatic hex to decimal conversion for `eth_blockNumber`
- ✅ **Configurable thresholds**: Default 120 block lag threshold for WARNING alerts
- ✅ **Trend analysis**: Detects if lag is increasing, decreasing, or stable
- ✅ **Smart alerting**: Reduces spam by analyzing patterns vs temporary spikes
- ✅ **Fast chain support**: Optimized for high-speed blockchains (~600 blocks/min)

### **3. Comprehensive Error Handling**
- ✅ **RPC timeout protection**: Configurable timeout (default 10 seconds)
- ✅ **Graceful degradation**: Local monitoring continues even if all external RPCs fail
- ✅ **Consecutive failure tracking**: Escalates alerts for persistent issues
- ✅ **Retry logic**: Intelligent retry mechanism for failed requests
- ✅ **Rate limiting protection**: Prevents RPC endpoint abuse

### **4. Advanced Alert System**

#### 🚨 **Critical Alerts**
- **Validator Removed from Active Set** - Immediate notification when `in_current_epoch = 0`
- **Metrics Endpoint Down** - Node completely unresponsive (3+ consecutive failures)

#### ⚠️ **Warning Alerts**  
- **Node Falling Behind Network** - Local node lagging > threshold blocks behind network
- **External RPC Endpoints Unavailable** - All external RPCs failing consistently
- **Local Block Sync Stalled** - Local node stopped producing/syncing blocks

#### ✅ **Success Alerts**
- **Validator Restored to Active Set** - Node back in validator rotation

### **5. Rich Discord Notifications**
- 🎨 **Color-coded embeds**: Red (Critical), Yellow (Warning), Green (Success)
- 📊 **Detailed diagnostics**: Block heights, lag analysis, trend information
- ⏰ **Timestamps**: All alerts include precise timing information
- 🏷️ **Node identification**: Custom node names and types in notifications
- 📈 **RPC status**: Success/failure status for all configured endpoints

### **6. Production-Ready Architecture**
- 🔒 **Lock file protection**: Prevents overlapping script executions
- 💾 **State persistence**: Tracks historical data and trends across runs
- 📝 **Comprehensive logging**: Detailed logs with timestamps and color coding
- 🔄 **Configuration validation**: Validates all settings on startup
- 🚀 **Future-proof design**: Easy to adapt for different blockchain networks

### **7. Operational Excellence**
- ⚡ **High-frequency monitoring**: Optimized for 2-5 minute check intervals
- 📊 **Performance metrics**: Block sync rates and timing analysis
- 🔍 **Debugging support**: Detailed RPC response logging and error tracking
- 📋 **Status reporting**: Clear differentiation between local vs network issues
- 🔧 **Easy maintenance**: Simple configuration file with clear documentation

## 📊 Example Multi-RPC Configuration

```bash
# Single RPC
EXTERNAL_RPCS="https://api.infra.mainnet.somnia.network"

# Multiple RPCs for redundancy
EXTERNAL_RPCS="https://api.infra.mainnet.somnia.network,https://backup-rpc.somnia.network,https://third-rpc.example.com"

# Disable external comparison (local monitoring only)
EXTERNAL_RPC_CHECK="no"
```

## 🛡️ Built for Mission-Critical Operations

This monitoring script is specifically designed for validator operations requiring **99.9% uptime** with:
- **Immediate alerting** for validator status changes
- **Network-aware monitoring** to distinguish local vs network issues  
- **Redundant monitoring paths** via multiple RPC endpoints
- **Intelligent false-positive reduction** through trend analysis
- **Comprehensive diagnostic information** for rapid troubleshooting
