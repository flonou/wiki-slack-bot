

module Commands
  class NyaBot
    def initialize
      facts = File.read("resources/nyaFacts.txt").split
    end
    def randomFact(webclient)
      fact = rand(0..facts.size-1)
      webclient.chat_postMessage(channel: channel, text: fact, as_user: true)
    end
  end
end
