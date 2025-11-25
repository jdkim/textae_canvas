# Annotation Canvas
## Environment
- Ruby 3.4.7
- Rails 8.1.1
- SQLite3 2.6.0
- Elasticsearch 8

## Installation

### Clone repository
```
git clone https://github.com/jdkim/textae_canvas.git
cd textae_canvas
```

### Option 1: VS Code DevContainer (Recommended)

The easiest way to set up the development environment is using VS Code with Dev Containers:

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Install [VS Code Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. Copy `.env.example` to `.env` and set your OpenAI API key
4. Open the repository in VS Code
5. Click "Reopen in Container" when prompted (or run "Dev Containers: Reopen in Container" from the Command Palette)

The environment will be automatically set up with all dependencies, database, and Elasticsearch.

For detailed instructions, see [.devcontainer/README.md](.devcontainer/README.md).

### Option 2: Docker Development Environment

You can also use Docker Compose directly without VS Code:

```bash
cd docker
docker compose up -d
docker compose exec web bash /workspaces/textae_canvas/docker/post-create.sh
```

For detailed instructions, see [docker/README.md](docker/README.md).

### Option 3: Manual Installation

### Install dependencies
```
bundle install
```

### Setup database
```
rails db:setup
```

### Google OAuth2 Setup Instructions

To obtain the required Google OAuth2 credentials:

1. **Create a Google Cloud Project** (if you don't have one):
    - Go to [Google Cloud Console](https://console.cloud.google.com/)
    - Create a new project or select an existing one

2. **Enable Google+ API**:
    - Navigate to "APIs & Services" > "Library"
    - Search for "Google+ API" and enable it

3. **Create OAuth 2.0 Credentials**:
    - Go to "APIs & Services" > "Credentials"
    - Click "Create Credentials" > "OAuth 2.0 Client IDs"
    - Choose "Web application" as the application type

4. **Configure Authorized Redirect URIs**:

   Add the following redirect URIs to your OAuth client configuration:

   **For Development (localhost):**
   ```
   http://localhost:3000/users/auth/google_oauth2/callback
   ```

   **For Production:**
   ```
   https://yourdomain.com/users/auth/google_oauth2/callback
   ```

   Replace `yourdomain.com` with your actual production domain.

5. **Get Your Credentials**:
    - After creating the OAuth client, copy the "Client ID" and "Client Secret"
    - Use these values for `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`

**Important Security Notes:**
- Never commit OAuth credentials to version control
- Use different OAuth clients for development and production environments
- Regularly rotate your client secrets for production applications

### Set environment variables

Create a `.env` file in the project root and configure the following environment variables:

```bash
# Google OAuth2 Credentials (required for authentication)
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here

# LLM Service Base URL (required for AI annotation features)
LLM_SERVICE_BASE_URL=http://localhost:3000
```

### Start the server
```
rails server
```

Now, you can access Annotation Canvas at http://localhost:3000.

## Elasticsearch setup
### Install Elasticsearch
Elasticsearch can be installed using the following command:
```
curl -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.19.0-darwin-x86_64.tar.gz
tar -xzf elasticsearch-8.19.0-darwin-x86_64.tar.gz
mv elasticsearch-8.19.0 /usr/local/elasticsearch
echo 'export PATH="/usr/local/elasticsearch/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```
### Start Elasticsearch
After installation, start Elasticsearch with the following command:
```
elasticsearch -d
```
## Create an index
To create an index for the Annotation Canvas, run the following command:
```
curl -X PUT "localhost:9200/smart_multilingual" -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "standard": {
          "filter": ["lowercase"],
          "tokenizer": "standard"
        }
      }
    }
  },
  "mappings": {
    "properties": {
      "content": {
        "type": "text",
        "analyzer": "standard"
      }
    }
  }
}'
```

## Code Formatting with Biome

This project uses Biome for JavaScript and CSS code formatting and linting.

### Install dependencies
```bash
npm install
```

### Check formatting
To check if your JavaScript and CSS files are formatted correctly:
```bash
npm run format:check
```

Or to check specific directories:
```bash
npx @biomejs/biome format app/javascript
npx @biomejs/biome format app/assets/stylesheets
```

### Format files
To automatically format JavaScript and CSS files:
```bash
npm run format
```

Or to format specific directories:
```bash
npx @biomejs/biome format --write app/javascript
npx @biomejs/biome format --write app/assets/stylesheets
```

### Run full check (format + lint)
To run both formatting and linting checks:
```bash
npm run check
```

To automatically fix issues:
```bash
npm run check:write
```
