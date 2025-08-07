const express = require('express');
const cors = require('cors');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// MCP Server Configuration
const mcpServers = {
  github: {
    name: 'GitHub MCP',
    url: process.env.GITHUB_MCP_URL || 'http://github-mcp:8080',
    description: 'GitHub repository and issue management',
    status: 'unknown'
  },
  sqlite: {
    name: 'SQLite MCP',
    url: process.env.SQLITE_MCP_URL || 'http://sqlite-mcp:8080',
    description: 'Local database operations',
    status: 'unknown'
  },
  filesystem: {
    name: 'Filesystem MCP',
    url: process.env.FILESYSTEM_MCP_URL || 'http://filesystem-mcp:8080',
    description: 'File system operations',
    status: 'unknown'
  },
  memory: {
    name: 'Memory MCP',
    url: process.env.MEMORY_MCP_URL || 'http://memory-mcp:8080',
    description: 'Context and memory management',
    status: 'unknown'
  },
  postgres: {
    name: 'PostgreSQL MCP',
    url: process.env.POSTGRES_MCP_URL || 'http://postgres-mcp:8080',
    description: 'PostgreSQL database operations',
    status: 'unknown'
  },
  web: {
    name: 'Web Search MCP',
    url: process.env.WEB_MCP_URL || 'http://web-mcp:8080',
    description: 'Web search and research',
    status: 'unknown'
  }
};

// Health check function
async function checkServerHealth(server) {
  try {
    const response = await axios.get(`${server.url}/health`, { timeout: 5000 });
    return response.status === 200 ? 'healthy' : 'unhealthy';
  } catch (error) {
    return 'unhealthy';
  }
}

// Update server statuses
async function updateServerStatuses() {
  for (const [key, server] of Object.entries(mcpServers)) {
    try {
      server.status = await checkServerHealth(server);
      server.lastChecked = new Date().toISOString();
    } catch (error) {
      server.status = 'error';
      server.error = error.message;
    }
  }
}

// Routes
app.get('/api/servers', async (req, res) => {
  await updateServerStatuses();
  res.json(mcpServers);
});

app.get('/api/servers/:id/status', async (req, res) => {
  const serverId = req.params.id;
  const server = mcpServers[serverId];
  
  if (!server) {
    return res.status(404).json({ error: 'Server not found' });
  }
  
  server.status = await checkServerHealth(server);
  server.lastChecked = new Date().toISOString();
  
  res.json({
    id: serverId,
    name: server.name,
    status: server.status,
    lastChecked: server.lastChecked
  });
});

app.post('/api/servers/:id/restart', async (req, res) => {
  const serverId = req.params.id;
  const server = mcpServers[serverId];
  
  if (!server) {
    return res.status(404).json({ error: 'Server not found' });
  }
  
  // In a real implementation, this would restart the Docker container
  // For now, we'll just return a success message
  res.json({ message: `Restart signal sent to ${server.name}` });
});

app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/api/stats', async (req, res) => {
  await updateServerStatuses();
  
  const totalServers = Object.keys(mcpServers).length;
  const healthyServers = Object.values(mcpServers).filter(s => s.status === 'healthy').length;
  const unhealthyServers = totalServers - healthyServers;
  
  res.json({
    totalServers,
    healthyServers,
    unhealthyServers,
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

// Serve the dashboard HTML
app.get('/', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI-First Company Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08);
            transition: transform 0.3s ease;
        }
        .stat-card:hover {
            transform: translateY(-5px);
        }
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 10px;
        }
        .stat-label {
            font-size: 1.1em;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .servers {
            padding: 30px;
        }
        .servers h2 {
            font-size: 2em;
            margin-bottom: 25px;
            color: #333;
        }
        .server-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 20px;
        }
        .server-card {
            background: white;
            border: 1px solid #e0e0e0;
            border-radius: 12px;
            padding: 25px;
            transition: all 0.3s ease;
            position: relative;
        }
        .server-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
        }
        .server-status {
            position: absolute;
            top: 15px;
            right: 15px;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #ccc;
        }
        .server-status.healthy {
            background: #4CAF50;
            box-shadow: 0 0 10px rgba(76, 175, 80, 0.3);
        }
        .server-status.unhealthy {
            background: #f44336;
            box-shadow: 0 0 10px rgba(244, 67, 54, 0.3);
        }
        .server-name {
            font-size: 1.4em;
            font-weight: bold;
            color: #333;
            margin-bottom: 10px;
        }
        .server-description {
            color: #666;
            margin-bottom: 15px;
            line-height: 1.5;
        }
        .server-actions {
            display: flex;
            gap: 10px;
            margin-top: 15px;
        }
        .btn {
            padding: 8px 16px;
            border: none;
            border-radius: 6px;
            cursor: pointer;
            font-size: 0.9em;
            transition: all 0.3s ease;
        }
        .btn-primary {
            background: #667eea;
            color: white;
        }
        .btn-primary:hover {
            background: #5a6fd8;
        }
        .btn-secondary {
            background: #f0f0f0;
            color: #333;
        }
        .btn-secondary:hover {
            background: #e0e0e0;
        }
        .refresh-btn {
            position: fixed;
            bottom: 30px;
            right: 30px;
            width: 60px;
            height: 60px;
            border-radius: 50%;
            background: #667eea;
            color: white;
            border: none;
            font-size: 1.5em;
            cursor: pointer;
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
            transition: all 0.3s ease;
        }
        .refresh-btn:hover {
            transform: scale(1.1);
            background: #5a6fd8;
        }
        .loading {
            display: none;
            text-align: center;
            padding: 20px;
            font-size: 1.1em;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 AI-First Company Dashboard</h1>
            <p>Manage your AI-powered MCP servers</p>
        </div>
        
        <div class="stats" id="stats">
            <div class="stat-card">
                <div class="stat-number" id="totalServers">-</div>
                <div class="stat-label">Total Servers</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="healthyServers">-</div>
                <div class="stat-label">Healthy</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="unhealthyServers">-</div>
                <div class="stat-label">Unhealthy</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="uptime">-</div>
                <div class="stat-label">Uptime (min)</div>
            </div>
        </div>
        
        <div class="servers">
            <h2>🔧 MCP Servers</h2>
            <div class="loading" id="loading">Loading servers...</div>
            <div class="server-grid" id="serverGrid"></div>
        </div>
    </div>
    
    <button class="refresh-btn" onclick="loadData()" title="Refresh">
        🔄
    </button>
    
    <script>
        async function loadData() {
            const loading = document.getElementById('loading');
            loading.style.display = 'block';
            
            try {
                // Load stats
                const statsResponse = await fetch('/api/stats');
                const stats = await statsResponse.json();
                
                document.getElementById('totalServers').textContent = stats.totalServers;
                document.getElementById('healthyServers').textContent = stats.healthyServers;
                document.getElementById('unhealthyServers').textContent = stats.unhealthyServers;
                document.getElementById('uptime').textContent = Math.floor(stats.uptime / 60);
                
                // Load servers
                const serversResponse = await fetch('/api/servers');
                const servers = await serversResponse.json();
                
                const serverGrid = document.getElementById('serverGrid');
                serverGrid.innerHTML = '';
                
                Object.entries(servers).forEach(([id, server]) => {
                    const serverCard = document.createElement('div');
                    serverCard.className = 'server-card';
                    serverCard.innerHTML = \`
                        <div class="server-status \${server.status}"></div>
                        <div class="server-name">\${server.name}</div>
                        <div class="server-description">\${server.description}</div>
                        <div>Status: <strong>\${server.status}</strong></div>
                        <div>Last checked: \${server.lastChecked ? new Date(server.lastChecked).toLocaleTimeString() : 'Never'}</div>
                        <div class="server-actions">
                            <button class="btn btn-primary" onclick="checkServer('\${id}')">Check Status</button>
                            <button class="btn btn-secondary" onclick="restartServer('\${id}')">Restart</button>
                        </div>
                    \`;
                    serverGrid.appendChild(serverCard);
                });
                
            } catch (error) {
                console.error('Error loading data:', error);
                document.getElementById('serverGrid').innerHTML = '<p>Error loading servers</p>';
            } finally {
                loading.style.display = 'none';
            }
        }
        
        async function checkServer(serverId) {
            try {
                const response = await fetch(\`/api/servers/\${serverId}/status\`);
                const result = await response.json();
                alert(\`\${result.name} is \${result.status}\`);
                loadData();
            } catch (error) {
                alert('Error checking server status');
            }
        }
        
        async function restartServer(serverId) {
            if (confirm('Are you sure you want to restart this server?')) {
                try {
                    const response = await fetch(\`/api/servers/\${serverId}/restart\`, {
                        method: 'POST'
                    });
                    const result = await response.json();
                    alert(result.message);
                    setTimeout(loadData, 2000);
                } catch (error) {
                    alert('Error restarting server');
                }
            }
        }
        
        // Load data on page load
        document.addEventListener('DOMContentLoaded', loadData);
        
        // Auto-refresh every 30 seconds
        setInterval(loadData, 30000);
    </script>
</body>
</html>
  `);
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Server error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
const server = app.listen(PORT, () => {
  console.log(`🚀 AI-First Dashboard running on port ${PORT}`);
  console.log(`📊 Dashboard URL: http://localhost:${PORT}`);
  
  // Initial health check
  setTimeout(updateServerStatuses, 5000);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

module.exports = app; 