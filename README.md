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

### Set OpenAI API key to environment variable
Create .env file and set the API key as below
```
OPENAI_API_KEY="Your api key here"
```

To obtain your api key, follow the OpenAI API key creation procedure below.

### Start the server
```
rails server
```

Now, you can access Annotation Canvas at http://localhost:3000.

## OpenAI API key creation procedure
### Step 1
API keys can be obtained from the OpenAI platform. Must be logged in.
```
https://platform.openai.com/api-keys
```

### Step 2
Click `+ Create new secret key` button on API keys page and generate secret key.   
The API key will be displayed immediately after creation, so please copy and keep it. Once this screen is closed, it cannot be displayed again.

### Step 3
Creation can be done without registering payment information, but you will need to purchase API credits to use the API.   
Move to billing page, set payment details and purchase credits.
```
https://platform.openai.com/settings/organization/billing/overview
```

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
