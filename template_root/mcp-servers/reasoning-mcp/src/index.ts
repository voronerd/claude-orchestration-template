import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import OpenAI from 'openai';

// Initialize reasoning model client (OpenAI-compatible API)
const reasoningClient = new OpenAI({
  apiKey: process.env.REASONING_API_KEY || 'dummy',
  baseURL: process.env.REASONING_API_BASE || 'http://localhost:8000/v1',
});

const DEFAULT_MODEL = process.env.REASONING_MODEL || 'default';

// Create MCP server
const server = new Server(
  {
    name: 'reasoning-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'reasoning_chat',
        description: 'Chat with a local reasoning model via OpenAI-compatible API. Connects to vLLM, TGI, or any OpenAI-compatible inference server.',
        inputSchema: {
          type: 'object',
          properties: {
            messages: {
              type: 'array',
              description: 'Array of chat messages',
              items: {
                type: 'object',
                properties: {
                  role: {
                    type: 'string',
                    enum: ['system', 'user', 'assistant'],
                    description: 'The role of the message author',
                  },
                  content: {
                    type: 'string',
                    description: 'The content of the message',
                  },
                },
                required: ['role', 'content'],
              },
            },
            model: {
              type: 'string',
              description: 'Model name (reads REASONING_MODEL env var if not specified)',
            },
          },
          required: ['messages'],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'reasoning_chat') {
    const messages = args?.messages as Array<{ role: 'system' | 'user' | 'assistant'; content: string }>;
    const model = (args?.model as string) || DEFAULT_MODEL;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      throw new Error('messages is required and must be a non-empty array');
    }

    try {
      const completion = await reasoningClient.chat.completions.create({
        model: model,
        messages: messages,
      });

      const responseContent = completion.choices[0]?.message?.content || '';

      return {
        content: [
          {
            type: 'text',
            text: responseContent,
          },
        ],
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      throw new Error(`Reasoning model API error: ${errorMessage}`);
    }
  }

  throw new Error(`Unknown tool: ${name}`);
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`Reasoning MCP server started (${process.env.REASONING_API_BASE || 'http://localhost:8000/v1'})`);
}

main().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
