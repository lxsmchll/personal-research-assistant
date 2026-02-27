# Personal Research Assistant - Setup Guide

## Overview

This guide will walk you through deploying your Personal Research Assistant from zero to production in ~2 hours.

## Prerequisites

- API of your chosen AI. For this one:
  - HuggingSpace API
  - Groq API
- Supabase account (free tier is fine)
- n8n instance (n8n.cloud or self-hosted)
- Slack workspace

---

## STEP 1: Supabase Setup (15 minutes)

### 1.1 Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Click "Start your project"
3. Create a new organization (if you don't have one)
4. Click "New project"
   - Name: `personal-research-assistant`
   - Database Password: (generate strong password, save it)
   - Region: Choose closest to you
   - Click "Create new project"
5. Wait ~2 minutes for project to initialize

### 1.2 Enable pgvector Extension

1. In Supabase dashboard, click "SQL Editor" (left sidebar)
2. Click "New query"
3. Copy the entire contents of `supabase_schema.sql`
4. Paste into the query editor
5. Click "Run" (or Ctrl/Cmd + Enter)
6. You should see "Success. No rows returned"

### 1.3 Get API Credentials

1. Click "Settings" (gear icon in left sidebar)
2. Click "API" in the settings menu
3. **SAVE THESE VALUES:**
   - **Project URL:** `https://xxxxx.supabase.co`
   - **Project API Key (anon/public):** `eyJhbGc...` (long string)
   - **Service Role Key:** `eyJhbGc...` (different long string)

---

## STEP 2: n8n Setup (20 minutes)

### 2.1 Create n8n Instance

**Option A: n8n Cloud (Recommended for beginners)**

1. Go to [n8n.io/cloud](https://n8n.io/cloud)
2. Sign up for free trial or paid plan
3. Create a new instance
4. Open your instance

**Option B: Self-hosted (Docker)**

```bash
# Run n8n locally
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

Then open http://localhost:5678

### 2.2 Install Required n8n Nodes

n8n comes with most nodes pre-installed, but verify you have:

- ✅ Webhook
- ✅ HTTP Request
- ✅ Supabase
- ✅ Groq
- ✅ HuggingSpace Embeddings
- ✅ Function / Code
- ✅ If
- ✅ Respond to Webhook

All of these should be available by default.

### 2.3 Add Credentials

**Groq Credential:**

1. In n8n, click "Credentials" in top menu
2. Click "Add Credential"
3. Search for "Groq"
4. Name: `Groq API`
5. API Key: Your Groq API key
6. Click "Save"

Do similar for the HuggingSpace API.

**Supabase Credential:**

1. Click "Add Credential" again
2. Search for "Supabase"
3. Name: `Supabase API`
4. Host: Your Supabase Project URL (from Step 1.3)
5. Service Role Secret: Your Service Role Key (from Step 1.3)
6. Click "Save"

---

## STEP 3: Import n8n Workflows (10 minutes)

### 3.1 Import "Add Document" Workflow

1. In n8n, click "Workflows" → "Add Workflow"
2. Click the "..." menu (top right) → "Import from File"
3. Select `add-document-workflow.json`
4. The workflow should appear on canvas

### 3.2 Update Credentials in Workflow

1. Click the embedding, supabase, and AI model nodes.
2. For each one, select the appropriate API credential accordingly.

### 3.3 Activate Webhook

1. Click on "Webhook - Slack /add-doc" node
2. Copy the "Production URL" (looks like: `https://your-instance.app.n8n.cloud/webhook/add-doc`)
3. **SAVE THIS URL** - you'll need it for Slack

### 3.4 Save and Activate Workflow

1. Click "Save" (top right)
2. Toggle "Active" switch (top right) to ON
3. Workflow should now show green "Active" badge

### 3.5 Repeat for "Ask Question" Workflow

1. Create another new workflow
2. Import `ask-question-workflow.json`
3. Update credentials
4. Copy webhook URL from "Webhook - Slack /ask" node
5. Save and activate

---

## STEP 4: Slack Setup (15 minutes)

### 4.1 Create Slack App

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Click "Create New App"
3. Choose "From scratch"
   - App Name: `Research Assistant`
   - Pick a workspace: Choose your test workspace
4. Click "Create App"

### 4.2 Create Slash Commands

1. In left sidebar, click "Slash Commands"
2. Click "Create New Command"

**First command:**

- Command: `/add-doc`
- Request URL: Your n8n webhook URL for "add-doc" workflow
- Short Description: `Add a PDF document to your research library`
- Usage Hint: `<PDF URL>`
- Click "Save"

3. Click "Create New Command" again

**Second command:**

- Command: `/ask`
- Request URL: Your n8n webhook URL for "ask" workflow
- Short Description: `Ask a question about your documents`
- Usage Hint: `<your question>`
- Click "Save"

### 4.3 Install App to Workspace

1. In left sidebar, click "Install App"
2. Click "Install to Workspace"
3. Review permissions and click "Allow"
4. You should see "App installed successfully"

---

## STEP 5: Test the System (10 minutes)

### 5.1 Find a Test PDF

Get a PDF URL to test with. Some options:

- Any PDF link you have
- arXiv paper: `https://arxiv.org/pdf/1706.03762.pdf` (famous "Attention is All You Need" paper)
- Any public PDF URL

### 5.2 Test Document Upload

1. Open Slack
2. Go to any channel
3. Type: `/add-doc https://arxiv.org/pdf/1706.03762.pdf`
4. Press Enter
5. Wait ~30 seconds
6. You should see a success message with document details

**If it fails:**

- Check n8n execution log (click "Executions" in n8n)
- Look for red error nodes
- Common issues: Wrong API keys, Supabase credentials not set, Python not enabled in n8n

### 5.3 Test Question Asking

1. In Slack, type: `/ask What is the transformer architecture?`
2. Press Enter
3. Wait ~10-15 seconds
4. You should see an AI-generated answer with citations

**Expected response should mention:**

- Attention mechanisms
- Encoder-decoder structure
- Citations to the document

## Usage

### Add a document:

```

/add-doc https://example.com/document.pdf

```

### Ask a question:

```

/ask What are the main findings in the research?

---

## Troubleshooting

### "No documents found when asking questions"

→ Check Supabase database - does `research_documents` table have data?

### "Slack command not working"

→ Verify webhook URL in Slack app matches your n8n webhook URL

### "Embedding dimension mismatch"

→ Make sure you're using the correct dimension to your AI model.

Good luck! 
```
