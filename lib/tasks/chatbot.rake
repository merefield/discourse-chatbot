desc "Update embeddings for each post"
task "chatbot:refresh_embeddings", %i[delay] => :environment do |_, args|
  ENV["RAILS_DB"] ? refresh_embeddings(args) : refresh_embeddings_all_sites(args)
end

desc "Refresh embeddings for all posts matching string/regex and optionally delay the loop"
task "chatbot:refresh_embeddings_match", %i[pattern type delay] => [:environment] do |_, args|
  args.with_defaults(type: "string")
  pattern = args[:pattern]
  type = args[:type]&.downcase
  delay = args[:delay]&.to_i

  if !pattern
    puts "ERROR: Expecting rake chatbot:refresh_embeddings_match[pattern,type,delay]"
    exit 1
  elsif delay && delay < 1
    puts "ERROR: delay parameter should be an integer and greater than 0"
    exit 1
  elsif type != "string" && type != "regex"
    puts "ERROR: Expecting rake chatbot:refresh_embeddings_match[pattern,type] where type is string or regex"
    exit 1
  end

  search = Post.raw_match(pattern, type)

  refreshed = 0
  total = search.count

  search.find_each do |post|
    post_embedding = ::DiscourseChatbot::EmbeddingProcess.new
    post_embedding.upsert_embedding(post.id)
    print_status(refreshed += 1, total)
    sleep(delay) if delay
  end

  puts "", "#{refreshed} posts done!", ""
end

def refresh_embeddings_all_sites(args)
  RailsMultisite::ConnectionManagement.each_connection { |db| refresh_embeddings(args)}
end

def refresh_embeddings(args)
  puts "Refreshing embeddings for all posts for '#{RailsMultisite::ConnectionManagement.current_db}'"

  delay = args[:delay]&.to_i

  if delay && delay < 1
    puts "ERROR: delay parameter should be an integer and greater than 0"
    exit 1
  end

  begin
    total = Post.count
    refreshed = 0
    batch = 1000
    
    (0..(total - 1).abs).step(batch) do |i|
      Post
        .order(id: :desc)
        .offset(i)
        .limit(batch)
        .each do |post|
          post_embedding = ::DiscourseChatbot::EmbeddingProcess.new
          post_embedding.upsert_embedding(post.id)
          print_status(refreshed += 1, total)
          sleep(delay) if delay
        end
    end
  end

  puts "", "#{refreshed} posts done!", "-" * 50
end
