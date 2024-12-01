#!/usr/bin/env ruby

# Source class to handle interactions (input/output)
class Source
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def tell(message)
    puts "#{name}: #{message}"
  end

  def ask(prompt)
    tell(prompt)
    gets.chomp
  end
end

# The Interview class, handling a single session
class Interview
  attr_reader :source

  def initialize(source)
    @source = source # Source object for interactions
  end

  # Determines if the initial prompt is accepted and returns nil if accepted, or a rejection reason otherwise
  def is_accepted?(starter)
    response = source.ask("Starting prompt: #{starter}\nDo you accept this as the starting point? (yes/no)").downcase

    case response
    when "no"
      rationale = source.ask("Why not? Please provide context:")
      source.tell("Thank you. Refining the context...")
      rationale # Return the rejection rationale
    when "yes", ""
      nil # Implicitly accept the starter
    else
      source.tell("Invalid response. Defaulting to 'yes'.")
      nil
    end
  end

  # Runs the interview phase and generates a new context
  def run(starter, finisher)
    current_context = starter

    # Refinement loop
    while true
      current_context = source.ask("Next: #{finisher}")

      if current_context.strip.length <= 3 # Short responses indicate termination
        confirm = source.ask("It sounds like you're done. Ready to move on? (yes/no)").downcase
        if confirm == "yes"
          source.tell("Moving to the next phase.\n")
          break
        else
          source.tell("Okay, let's refine further.")
        end
      else
        break
      end
    end

    current_context.strip # Return the final updated context
  end
end

# The Harmonize class, orchestrating the process with two interviews
class Harmonize
  attr_reader :prompts, :sources, :interviews, :contexts

  def initialize(prompts, sources)
    @prompts = prompts          # List of prompts for the process
    @sources = sources          # Hash of sources (e.g., { ernest: Source, sage: Source })
    @contexts = []              # List of all contexts generated during the process
    @interviews = {
      prior: Interview.new(sources[:ernest]),  # Prior interview
      current: Interview.new(sources[:sage])  # Current interview
    }
  end

  def run(default_context)
    @contexts << default_context # Add the initial context
    puts "=== Self-Harmonization Workflow ===\n"

    @prompts.each_with_index do |phase, index|
      while true
        puts "Phase #{index + 1}:"

        # Get the current interview
        current_interview = @interviews[:current]
        starter = @contexts.last

        # Check if the starter context is accepted
        rationale = current_interview.is_accepted?(starter)
        if rationale
          # Revisit prior interview to refine the latest context
          prior_interview = @interviews[:prior]
          revised_context = prior_interview.run("#{starter} (Revised: #{rationale})", "Can you revisit and refine this?")
          @contexts << revised_context # Add the refined context to the list
          puts "Revised Context: #{revised_context}"
        else
          # Run the current interview and add the new context
          new_context = current_interview.run(starter, phase[:finisher])
          @contexts << new_context
          puts "New Context: #{new_context}"
          break
        end
      end

      # Swap interviews for the next phase
      swap_interviews
    end

    puts "=== Workflow Complete ==="
    puts "All Contexts: #{@contexts.inspect}"
    puts "Final Output: #{@contexts.last}"
  end

  private

  def swap_interviews
    @interviews[:prior], @interviews[:current] = @interviews[:current], @interviews[:prior]
  end
end

# Default prompts definition
prompts = [
  { starter: "What is your concern?", finisher: "Can you refine this into something actionable?" },
  { starter: "What is the problem?", finisher: "Can you make this problem more specific?" },
  { starter: "What are some solutions?", finisher: "Can you narrow it down to the best options?" },
  { starter: "Which solution is best?", finisher: "Does this solution align with your goals?" },
  { starter: "Are we ready to validate?", finisher: "Does this feel like the right solution?" },
  { starter: "How will you execute?", finisher: "What steps are required to implement this solution?" }
]

# Main execution
if __FILE__ == $0
  # Create sources
  sources = {
    ernest: Source.new("Ernest (Intuition)"),
    sage: Source.new("Sage (Logic)")
  }

  # Initialize Harmonize with prompts and sources
  harmonize = Harmonize.new(prompts, sources)

  # Run the process with a default initial context
  harmonize.run("What is the most important challenge you would like to work on?")
end
