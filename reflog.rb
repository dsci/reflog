# require bundler first!
require 'bundler/setup'

libraries = %w(grit sinatra/base json mimemagic gravatar-ultimate time-lord yaml)
libraries.each{|library| require library}

begin
  # Set up load paths for all bundled gems
  #ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems." +
    "Did you run `bundle install`?"
end

module Reflog

  class GridConfig
    
    CONFIG_PATH = File.expand_path(File.join(File.dirname(__FILE__), 'git.yml'))
    
    class << self
      
      def repository
        YAML::load_file(CONFIG_PATH)["repository"]
      rescue
        raise "Invalid repository!"
      end
    
      def branch
        YAML::load_file(CONFIG_PATH)["branch"]
      rescue
        "master"
      end
      
    end
  end

  class Application < Sinatra::Base
    
    use Rack::Session::Pool, :expire_after => 2592000
    
    helpers do
      
      def branch
        @branch ||= GridConfig.branch
      end
      
      def repo
        @repo ||= Grit::Repo.new(GridConfig.repository)
      end
      
      def gravatar_for_author(actor)
        Gravatar.new(actor).image_url
      end
      
      def author_icon(head)
        @author_icon = gravatar_for_author(head.author.email)
      end
      
      def committed_date_in_words(date)
        date.ago_in_words
      end
      
      def contents_of_tree(tree)
        @directories = []
        @files = []

        tree.contents.each do |node|
          attrs = {:name => node.name,
                   :id => node.id}
          @directories << attrs if node.is_a?(Grit::Tree)
          @files << attrs if node.is_a?(Grit::Blob)
        end
      end
      
      def format_head_message(head_message)
        splitted_messages = head_message.split("\n")
        header = splitted_messages.shift
        return <<-MESSAGE
              <strong>#{header}</strong>
              <blockquote><p>#{splitted_messages.join(" ")}</p></blockquote>
              MESSAGE
      end
      
      def formatted_commit_data
        @committed_date = committed_date_in_words(@head.committed_date)
        @commit_message = format_head_message(@head.message)
      end
      
      def commits_for_branch(branch_name)
        @commits = repo.commits(branch_name)
      end
    end
    
    configure do
      set :public_folder, File.dirname(__FILE__) + '/static'
    end
  
  
    before do
      #content_type :json
      @branches = repo.heads.map(&:name)
      @tags = repo.tags.map(&:name)
      @description = repo.description
      @git_url = repo.path
    end
    
    get '/' do
      @commits = commits_for_branch(branch)
      @head = @commits.first
      formatted_commit_data
      tree = @head.tree
      contents_of_tree(@head.tree)
      author_icon(@head)
      session[:path] = nil
      @tree_path = "/"
      @branch = branch
      erb :index
    end
    
    get '/tree/*' do
      #p branch
      path = params[:splat].first.to_s.split("/")
      #branch is always the first element!
      @branch = path.shift
      session[:path] = path.join("/")
      @tree_path = "/" + session[:path] + "/" unless path.empty?
      @tree_path ="/" if path.empty?
      @commits = commits_for_branch(@branch)
      @head = @commits.first
      contents_of_tree(@head.tree/(path.join("/"))) unless path.empty?
      contents_of_tree(@head.tree) if path.empty?
      formatted_commit_data
      author_icon(@head)
      erb :index
    end
    
    get '/blob/*' do
      begin
        path = params[:splat].first.to_s.split("/")
        #branch is always the first element!
        @branch = path.shift
        @head = repo.commits(@branch).first
        @blob = @head.tree/(path.join("/"))
        formatted_commit_data
        author_icon(@head)
        @name = @blob.name
      
        erb :blob
      rescue
        attachment(@blob.name)
        @blob.data
      end
    end
    
    get '/commit/:id' do
      @commit = repo.commit(params[:id])
      p @commit.diffs
    end
    
    get '/download/blob/:id/:name' do
      blob = repo.blob(params[:id])
      attachment(params[:name])
      blob.data
    end
    
    get '/login' do
      erb :login_form
    end
    
  end
end

