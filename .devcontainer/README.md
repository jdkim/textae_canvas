# DevContainer環境

このディレクトリには、Visual Studio Code Dev Containersの設定が含まれています。

## 前提条件

- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers拡張機能](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)

## 使用方法

1. **リポジトリをクローン:**
   ```bash
   git clone https://github.com/jdkim/textae_canvas.git
   cd textae_canvas
   ```

2. **環境変数を設定:**
   
   `.env.example`をコピーして`.env`を作成し、必要な環境変数を設定します：
   ```bash
   cp .env.example .env
   ```
   
   `.env`ファイルを編集して、以下の変数を設定：
   ```
   OPENAI_API_KEY=your_openai_api_key_here
   GOOGLE_CLIENT_ID=your_google_client_id_here
   GOOGLE_CLIENT_SECRET=your_google_client_secret_here
   LLM_SERVICE_BASE_URL=http://localhost:3000
   ```

3. **VS CodeでDevContainerを開く:**
   
   VS Codeでリポジトリを開き、次のいずれかの方法を使用します：
   
   - コマンドパレット（`F1`または`Ctrl+Shift+P`）を開き、「Dev Containers: Reopen in Container」を選択
   - または、VS Codeがプロンプトで「Reopen in Container」を表示したらクリック

4. **自動セットアップ:**
   
   コンテナが起動すると、以下が自動的に実行されます：
   - Rubyの依存関係のインストール
   - データベースのセットアップ
   - Elasticsearchインデックスの作成
   - Node.jsパッケージのインストール

5. **アプリケーションへのアクセス:**
   - アプリケーション: http://localhost:3000
   - Elasticsearch: http://localhost:9200

## 含まれる機能

### VSCode拡張機能

以下の拡張機能が自動的にインストールされます：

- **Ruby LSP**: Ruby言語サーバーによるインテリセンス
- **Solargraph**: Ruby開発ツール
- **RuboCop**: Rubyコードのlinting
- **Biome**: JavaScript/CSSのフォーマットとlinting
- **Docker**: Docker管理

### 開発ツール

- Git
- Ruby 3.4.7
- Node.js 20
- Bundler
- Rails 8.1.1
- SQLite3 2.7.4
- Elasticsearch 8

## 便利なコマンド

コンテナ内で以下のコマンドを実行できます：

### Railsアプリケーション

```bash
# サーバーを起動（docker-compose.ymlで自動起動）
bin/rails server

# Railsコンソールを開く
bin/rails console

# テストを実行
bin/rails test

# データベースのリセット
bin/rails db:reset
```

### コードフォーマット

```bash
# Biomeでフォーマット
npm run format

# RuboCopでRubyコードをチェック
bundle exec rubocop

# RuboCopで自動修正
bundle exec rubocop -a
```

## トラブルシューティング

### コンテナが起動しない

1. Docker Desktopが起動していることを確認
2. VS Codeを再起動
3. コマンドパレットから「Dev Containers: Rebuild Container」を実行

### データベースエラー

コンテナ内で以下を実行：
```bash
bin/rails db:reset
```

### Elasticsearchに接続できない

Elasticsearchサービスが起動していることを確認：
```bash
curl http://es:9200
```

## 従来のDocker環境との違い

DevContainer環境を使用すると：

- VS Codeがコンテナ内で直接実行されるため、シームレスな開発体験が得られます
- 拡張機能とツールが自動的にセットアップされます
- ターミナルがコンテナ内で直接実行されます
- ファイルシステムのパフォーマンスが向上します

従来のDocker環境（`docker/`ディレクトリ）は引き続き利用可能で、DevContainerを使用しない場合に使用できます。
