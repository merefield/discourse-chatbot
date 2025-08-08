# Chatbot Advanced - Token Usage Tracking and Cost Management

This feature provides comprehensive tracking of token usage and associated costs for the Discourse Chatbot Advanced plugin.

**Developed by:** DigneZzZ  
**Plugin:** discourse-chatbot-advanced  
**Version:** 1.6.0+

## Features

### 1. Token Usage Tracking
- **Detailed Logging**: Tracks input tokens, output tokens, and total tokens for each request
- **Cost Calculation**: Automatically calculates costs based on current model pricing
- **Request Types**: Supports different request types (chat, embedding, vision, image_generation)
- **Model-Specific**: Tracks usage per AI model (GPT-4, GPT-5, O-series, etc.)

### 2. Cost Management
- **Real-time Cost Tracking**: Monitor spending in real-time
- **Model Pricing**: Built-in pricing information for all supported models
- **Currency Support**: All costs tracked in USD
- **Historical Data**: Maintains historical usage data for analysis

### 3. Analytics Dashboard
- **Overview Dashboard**: Total costs, tokens, requests, and active users
- **Usage Charts**: Visual representation of daily usage patterns
- **Model Statistics**: Breakdown by AI model and request type
- **Top Users**: Identify heaviest users of the system
- **Export Functionality**: Export data in CSV or JSON format

### 4. Administrative Features
- **Admin Panel**: Dedicated admin interface at `/admin/plugins/discourse-chatbot/token-stats`
- **Data Retention**: Configurable data retention period (30-365 days)
- **Automatic Cleanup**: Weekly cleanup of old data
- **Manual Cleanup**: Option to manually clean old records

## Configuration

### Settings

```yaml
chatbot_enable_token_usage_tracking: true  # Enable/disable tracking
chatbot_token_usage_retention_days: 90     # Data retention period
```

### Database

The feature uses a new table `chatbot_token_usage` with the following schema:

```sql
CREATE TABLE chatbot_token_usage (
  id bigint PRIMARY KEY,
  user_id integer NOT NULL,
  model_name varchar NOT NULL,
  request_type varchar NOT NULL,
  input_tokens integer DEFAULT 0,
  output_tokens integer DEFAULT 0,
  total_tokens integer NOT NULL,
  input_cost decimal(10,6) DEFAULT 0.0,
  output_cost decimal(10,6) DEFAULT 0.0,
  total_cost decimal(10,6) NOT NULL,
  currency varchar DEFAULT 'USD',
  metadata text,
  topic_id integer,
  post_id integer,
  chat_message_id integer,
  created_at timestamp,
  updated_at timestamp
);
```

## API Endpoints

### Admin Token Statistics

All endpoints require staff permissions and are prefixed with `/chatbot/admin/token-stats/`:

- `GET /usage` - Get usage statistics for a period
- `GET /models` - Get model-specific statistics  
- `GET /users` - Get user-specific statistics
- `GET /export` - Export usage data (CSV/JSON)
- `DELETE /cleanup` - Cleanup old data

### Example API Response

```json
{
  "system_stats": {
    "total_requests": 1234,
    "total_users": 56,
    "total_tokens": 987654,
    "total_cost": 12.34,
    "by_model": {
      "gpt-4o-mini": 5.67,
      "gpt-5": 6.67
    },
    "by_type": {
      "chat": 10.50,
      "embedding": 1.84
    }
  },
  "daily_stats": {
    "2025-08-01": {
      "gpt-4o-mini": {
        "cost": 2.15,
        "tokens": 12000
      }
    }
  },
  "top_users": [
    {
      "username": "alice",
      "user_id": 123,
      "total_cost": 3.45,
      "total_tokens": 23000
    }
  ]
}
```

## Cost Calculation

### Model Pricing (per 1000 tokens)

| Model | Input Cost | Output Cost |
|-------|------------|-------------|
| GPT-4o-mini | $0.00015 | $0.0006 |
| GPT-4o | $0.005 | $0.015 |
| GPT-5 | $0.002 | $0.008 |
| GPT-5-mini | $0.00008 | $0.0003 |
| O1 | $0.015 | $0.06 |
| O3 | $0.02 | $0.08 |

*Note: Prices are estimates and may vary. Check OpenAI pricing for current rates.*

### Special Cases

- **Embedding Models**: Only input tokens are charged
- **Image Generation**: Charged per image, not per token
- **Vision Models**: Both input and output tokens are charged

## Usage Examples

### Checking User Usage

```ruby
# Get user's usage summary for this month
summary = TokenUsageLogger.get_user_usage_summary(user_id, 'this_month')

puts "Total cost: $#{summary[:total_cost]}"
puts "Total tokens: #{summary[:total_tokens]}"
puts "Total requests: #{summary[:total_requests]}"
```

### System-wide Statistics

```ruby
# Get system usage summary
stats = TokenUsageLogger.get_system_usage_summary('this_week')

puts "System-wide cost: $#{stats[:total_cost]}"
puts "Active users: #{stats[:total_users]}"
```

### Manual Token Logging

```ruby
# Log a chat request
TokenUsageLogger.log_chat_usage(
  user_id: 123,
  model_name: 'gpt-4o-mini',
  input_tokens: 150,
  output_tokens: 75,
  topic_id: 456,
  post_id: 789
)

# Log an embedding request
TokenUsageLogger.log_embedding_usage(
  user_id: 123,
  model_name: 'text-embedding-3-small',
  tokens: 200,
  post_id: 789
)
```

## Monitoring and Alerts

### Automated Cleanup

The system automatically cleans up old token usage data based on the retention period:

```ruby
# Runs weekly via scheduled job
Jobs::ChatbotTokenUsageCleanup.new.execute({})
```

### Manual Cleanup

```ruby
# Clean records older than 90 days
deleted_count = TokenUsageLogger.cleanup_old_records(90)
```

## Security and Privacy

- **Staff Only**: All admin endpoints require staff permissions
- **Data Anonymization**: Export functions can anonymize user data
- **Retention Limits**: Configurable data retention prevents indefinite storage
- **Audit Trail**: All token usage is logged for accountability

## Performance Considerations

- **Async Logging**: Token usage is logged asynchronously to avoid blocking requests
- **Indexed Queries**: Database indexes optimize common queries
- **Batch Operations**: Cleanup operations use batch processing
- **Memory Efficient**: Streaming used for large data exports

## Troubleshooting

### Common Issues

1. **Missing Token Data**: Ensure `chatbot_enable_token_usage_tracking` is enabled
2. **Incorrect Costs**: Verify model pricing in `TokenCostCalculator`
3. **Performance Issues**: Check database indexes and consider reducing retention period
4. **Admin Access**: Ensure user has staff permissions

### Debug Logging

Enable verbose logging to troubleshoot issues:

```yaml
chatbot_enable_verbose_rails_logging: 'all'
chatbot_verbose_rails_logging_destination_level: 'info'
```

## Future Enhancements

- **Budget Alerts**: Notifications when costs exceed thresholds
- **Usage Predictions**: Forecast future usage based on trends
- **Custom Pricing**: Support for custom model pricing
- **Advanced Analytics**: More detailed analytics and reporting
- **API Rate Limiting**: Integration with token-based rate limiting
