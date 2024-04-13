# frozen_string_literal: true
desc "Update embeddings for each post"
task "chatbot:refresh_embeddings", %i[missing_only delay] => :environment do |_, args|
  ENV["RAILS_DB"] ? refresh_embeddings(args) : refresh_embeddings_all_sites(args)
end

def refresh_embeddings_all_sites(args)
  RailsMultisite::ConnectionManagement.each_connection { |db| refresh_embeddings(args) }
end

def refresh_embeddings(args)
  puts "-" * 50
  puts "Refreshing embeddings for posts and topic titles for '#{RailsMultisite::ConnectionManagement.current_db}'"
  puts "-" * 50

  missing_only = args[:missing_only]&.to_i
  delay = args[:delay]&.to_i

  puts "for missing only" if !missing_only.to_i.zero?
  puts "with a delay of #{delay} second(s) between API calls" if !delay.to_i.zero?
  puts "-" * 50

  if delay && delay < 1
    puts "ERROR: delay parameter should be an integer and greater than 0"
    exit 1
  end

  begin
    total = Post.count
    refreshed = 0
    batch = 1000

    process_post_embedding = ::DiscourseChatbot::PostEmbeddingProcess.new

    (0..(total - 1).abs).step(batch) do |i|
      Post
        .order(id: :desc)
        .offset(i)
        .limit(batch)
        .each do |post|
          if !missing_only.to_i.zero? && ::DiscourseChatbot::PostEmbedding.find_by(post_id: post.id).nil? || missing_only.to_i.zero?
            process_post_embedding.upsert(post.id)
            sleep(delay) if delay
          end
          print_status(refreshed += 1, total)
        end
    end
  end

  puts "", "#{refreshed} posts done!", "-" * 50

  begin
    total = Topic.count
    refreshed = 0
    batch = 1000

    process_topic_title_embedding = ::DiscourseChatbot::TopicTitleEmbeddingProcess.new

    (0..(total - 1).abs).step(batch) do |i|
      Topic
        .order(id: :desc)
        .offset(i)
        .limit(batch)
        .each do |topic|
          if !missing_only.to_i.zero? && ::DiscourseChatbot::TopicTitleEmbedding.find_by(topic_id: topic.id).nil? || missing_only.to_i.zero?
            process_post_embedding.upsert(topic.id)
            sleep(delay) if delay
          end
          print_status(refreshed += 1, total)
        end
    end
  end

  puts "", "#{refreshed} topic titles done!", "-" * 50
end
