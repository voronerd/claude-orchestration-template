import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import OpenAI from 'openai';

// Initialize Grok client (OpenAI-compatible API)
const grok = new OpenAI({
  apiKey: process.env.GROK_API_KEY,
  baseURL: 'https://api.x.ai/v1',
});

// Supported Grok models
const MODELS = [
  'grok-4-0709',
  'grok-3',
  'grok-3-fast',
  'grok-2',
] as const;

const DEFAULT_MODEL = 'grok-4-0709';

// Create MCP server
const server = new Server(
  {
    name: 'grok-mcp',
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
        name: 'grok_chat',
        description: 'Chat with xAI Grok models. Grok offers a unique perspective with real-time knowledge and contrarian thinking.',
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
              enum: MODELS,
              default: DEFAULT_MODEL,
              description: 'The Grok model to use',
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

  if (name === 'grok_chat') {
    const messages = args?.messages as Array<{ role: 'system' | 'user' | 'assistant'; content: string }>;
    const model = (args?.model as string) || DEFAULT_MODEL;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      throw new Error('messages is required and must be a non-empty array');
    }

    try {
      const completion = await grok.chat.completions.create({
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
      throw new Error(`Grok API error: ${errorMessage}`);
    }
  }

  throw new Error(`Unknown tool: ${name}`);
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Grok MCP server started');
}

main().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
