module SpecHelpers
  module CommitResponse
    def response(status = nil, body = nil, &block)
      unless block
        block = lambda { REST::Response.new(status, {}, body) }
      end
      Pod::TrunkApp::GitHub::CreateCommitResponse.new(&block)
    end
  end
end

