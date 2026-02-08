import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import OpenAI from 'openai';

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Supported models
const MODELS = [
  'gpt-4.1',
  'gpt-4.1-mini',
  'gpt-4.1-nano',
  'gpt-4o',
  'gpt-4o-mini',
  'o3',
  'o3-mini',
  'o3-pro',
  'o4-mini',
] as const;

const DEFAULT_MODEL = 'gpt-4.1';

// Create MCP server
const server = new Server(
  {
    name: 'openai-mcp',
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
        name: 'openai_chat',
        description: 'Chat with OpenAI models. Supports GPT-4.1 series, GPT-4o series, and O-series reasoning models.',
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
              description: 'The OpenAI model to use',
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

  if (name === 'openai_chat') {
    const messages = args?.messages as Array<{ role: 'system' | 'user' | 'assistant'; content: string }>;
    const model = (args?.model as string) || DEFAULT_MODEL;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      throw new Error('messages is required and must be a non-empty array');
    }

    try {
      const completion = await openai.chat.completions.create({
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
      throw new Error(`OpenAI API error: ${errorMessage}`);
    }
  }

  throw new Error(`Unknown tool: ${name}`);
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('OpenAI MCP server started');
}

main().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
