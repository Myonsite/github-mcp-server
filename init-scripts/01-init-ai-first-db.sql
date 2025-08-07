-- AI-First Company Database Initialization Script
-- This script creates the necessary tables and data for AI-first operations

-- Create extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create projects table
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    repository_url VARCHAR(500),
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    priority VARCHAR(20) DEFAULT 'medium',
    assigned_to VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Create metrics table
CREATE TABLE IF NOT EXISTS metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id),
    metric_type VARCHAR(100) NOT NULL,
    metric_name VARCHAR(255) NOT NULL,
    metric_value DECIMAL(10,2),
    metadata JSONB,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create automation_logs table
CREATE TABLE IF NOT EXISTS automation_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id),
    action VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    details JSONB,
    duration_ms INTEGER,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create ai_interactions table
CREATE TABLE IF NOT EXISTS ai_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id),
    interaction_type VARCHAR(100) NOT NULL,
    prompt TEXT,
    response TEXT,
    model_used VARCHAR(100),
    tokens_used INTEGER,
    cost DECIMAL(10,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create knowledge_base table
CREATE TABLE IF NOT EXISTS knowledge_base (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id),
    title VARCHAR(255) NOT NULL,
    content TEXT,
    category VARCHAR(100),
    tags TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_metrics_project_id ON metrics(project_id);
CREATE INDEX IF NOT EXISTS idx_metrics_type ON metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_automation_logs_project_id ON automation_logs(project_id);
CREATE INDEX IF NOT EXISTS idx_automation_logs_executed_at ON automation_logs(executed_at);
CREATE INDEX IF NOT EXISTS idx_ai_interactions_project_id ON ai_interactions(project_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_project_id ON knowledge_base(project_id);

-- Insert sample data
INSERT INTO projects (name, description, repository_url, status) VALUES
('AI-First Transformation', 'Complete AI-first company transformation project', 'https://github.com/user/ai-first-transformation', 'active'),
('Customer Portal', 'Modern customer portal with AI integration', 'https://github.com/user/customer-portal', 'active'),
('Data Analytics Platform', 'AI-powered data analytics and insights platform', 'https://github.com/user/data-analytics', 'planning');

-- Insert sample tasks
INSERT INTO tasks (project_id, title, description, status, priority) VALUES
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'Setup MCP Servers', 'Configure and deploy all MCP servers', 'completed', 'high'),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'Create Documentation', 'Write comprehensive documentation', 'completed', 'medium'),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'Deploy to Production', 'Deploy the complete system to production', 'in_progress', 'high'),
((SELECT id FROM projects WHERE name = 'Customer Portal'), 'Design UI/UX', 'Create modern user interface designs', 'pending', 'medium'),
((SELECT id FROM projects WHERE name = 'Customer Portal'), 'Implement Authentication', 'Setup user authentication system', 'pending', 'high');

-- Insert sample metrics
INSERT INTO metrics (project_id, metric_type, metric_name, metric_value, metadata) VALUES
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'productivity', 'Tasks Completed', 15, '{"period": "week", "team_size": 3}'),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'efficiency', 'Automation Coverage', 85.5, '{"total_processes": 20, "automated_processes": 17}'),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'cost_savings', 'Time Saved (hours)', 120, '{"manual_time": 150, "automated_time": 30}');

-- Insert sample automation logs
INSERT INTO automation_logs (project_id, action, status, details, duration_ms) VALUES
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'deploy_mcp_servers', 'success', '{"servers_deployed": 6, "containers_started": 8}', 45000),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'run_tests', 'success', '{"tests_passed": 27, "tests_failed": 0}', 12000),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'generate_documentation', 'success', '{"files_created": 14, "words_generated": 25000}', 8000);

-- Insert sample AI interactions
INSERT INTO ai_interactions (project_id, interaction_type, prompt, response, model_used, tokens_used, cost) VALUES
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'code_generation', 'Create a Docker Compose file for MCP servers', 'Generated comprehensive Docker Compose configuration...', 'claude-3-sonnet', 2500, 0.125),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'documentation', 'Write setup guide for AI-first transformation', 'Created detailed step-by-step setup guide...', 'claude-3-sonnet', 3200, 0.160),
((SELECT id FROM projects WHERE name = 'Customer Portal'), 'planning', 'Design database schema for customer portal', 'Designed normalized database schema with proper relationships...', 'claude-3-sonnet', 1800, 0.090);

-- Insert sample knowledge base entries
INSERT INTO knowledge_base (project_id, title, content, category, tags) VALUES
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'MCP Server Configuration', 'Complete guide to configuring MCP servers for AI-first operations...', 'configuration', ARRAY['mcp', 'docker', 'ai-first']),
((SELECT id FROM projects WHERE name = 'AI-First Transformation'), 'Docker Deployment Best Practices', 'Best practices for deploying AI-first toolkit using Docker...', 'deployment', ARRAY['docker', 'deployment', 'best-practices']),
((SELECT id FROM projects WHERE name = 'Customer Portal'), 'API Design Guidelines', 'Guidelines for designing RESTful APIs for the customer portal...', 'development', ARRAY['api', 'rest', 'design']);

-- Create functions for common operations
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at columns
CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_knowledge_base_updated_at BEFORE UPDATE ON knowledge_base FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create views for common queries
CREATE OR REPLACE VIEW project_summary AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.status,
    COUNT(t.id) as total_tasks,
    COUNT(CASE WHEN t.status = 'completed' THEN 1 END) as completed_tasks,
    COUNT(CASE WHEN t.status = 'in_progress' THEN 1 END) as in_progress_tasks,
    COUNT(CASE WHEN t.status = 'pending' THEN 1 END) as pending_tasks,
    p.created_at,
    p.updated_at
FROM projects p
LEFT JOIN tasks t ON p.id = t.project_id
GROUP BY p.id, p.name, p.description, p.status, p.created_at, p.updated_at;

CREATE OR REPLACE VIEW recent_ai_interactions AS
SELECT 
    ai.id,
    p.name as project_name,
    ai.interaction_type,
    ai.prompt,
    LEFT(ai.response, 100) as response_preview,
    ai.model_used,
    ai.tokens_used,
    ai.cost,
    ai.created_at
FROM ai_interactions ai
JOIN projects p ON ai.project_id = p.id
ORDER BY ai.created_at DESC
LIMIT 50;

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ai_first_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ai_first_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO ai_first_user;

-- Success message
DO $$ 
BEGIN 
    RAISE NOTICE 'AI-First Company database initialized successfully!';
    RAISE NOTICE 'Created % tables with sample data', (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public');
END $$; 