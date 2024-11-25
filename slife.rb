require 'rubyplot'

# Configuration constants
CONFIG = {
  grid_size: 50,
  initial_cells: 100,
  food_capacity: 5,
  food_consumption_rate: 0.1,
  camp_decay: 0.1,
  amplification_factor: 1.5,
  refractory_period: 5
}

# Grid utilities for common operations
module GridUtils
  def self.neighbors(coord)
    x, y = coord
    [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]
  end

  def self.prune_empty_sites!(grid)
    grid.delete_if { |_coord, state| state.values_at(:mold, :food, :camp).all?(&:zero?) }
  end
end

# Abstract base class for behaviors
class Behavior
  def apply(grid, next_grid)
    grid.each do |coord, state|
      next unless process_site?(state)
      process_site(grid, next_grid, coord, state)
    end
  end

  protected

  def process_site?(state)
    true
  end

  def process_site(grid, next_grid, coord, state)
    raise NotImplementedError, 'Subclasses must implement the process_site method'
  end

  def ranked_neighbors(grid, coord)
    GridUtils.neighbors(coord).sort_by { |neighbor| [-grid[neighbor][:camp], grid[neighbor][:mold]] }
  end
end

# FoodBehavior: Mold consumes nutrients and generates cAMP
class FoodBehavior < Behavior
  protected

  def process_site?(state)
    state[:mold] > 0 && state[:food] >= CONFIG[:food_consumption_rate]
  end

  def process_site(grid, next_grid, coord, state)
    food_consumed = CONFIG[:food_consumption_rate] * state[:mold]
    next_grid[coord][:camp] += food_consumed * CONFIG[:amplification_factor]
    next_grid[coord][:food] -= food_consumed
  end
end

# CampBehavior: Handles cAMP propagation and decay
class CampBehavior < Behavior
  def apply(grid, next_grid)
    new_camp = Hash.new(0)

    grid.each do |coord, state|
      camp = state[:camp] * (1 - CONFIG[:camp_decay])  # Apply decay
      GridUtils.neighbors(coord).each do |neighbor|
        new_camp[neighbor] += camp * 0.25  # Distribute equally to neighbors
      end
    end

    # Add propagated cAMP back to the grid
    new_camp.each { |coord, camp| next_grid[coord][:camp] += camp }
  end
end

# MoldBehavior: Mold redistributes based on cAMP gradients
class MoldBehavior < Behavior
  protected

  def process_site?(state)
    state[:mold] > 0
  end

  def process_site(grid, next_grid, coord, state)
    total_mold = state[:mold]
    neighbors = ranked_neighbors(grid, coord)

    # Distribute mold to neighbors proportionally to their cAMP levels
    total_camp = neighbors.sum { |neighbor| grid[neighbor][:camp] }
    neighbors.each do |neighbor|
      weight = total_camp > 0 ? grid[neighbor][:camp] / total_camp : 1.0 / neighbors.size
      next_grid[neighbor][:mold] += total_mold * weight
    end
  end
end

# Simulation class orchestrates the entire simulation lifecycle
class Simulation
  attr_reader :history

  def initialize
    @current_grid = initialize_grid
    @history = []
  end

  def step
    next_grid = Hash.new { |hash, key| hash[key] = { mold: 0, food: 0, camp: 0, refractory: 0 } }

    # Apply each behavior in sequence
    behaviors.each { |behavior| behavior.apply(@current_grid, next_grid) }

    GridUtils.prune_empty_sites!(next_grid)
    next_grid
  end

  def run(steps)
    steps.times do
      @history << @current_grid.dup
      @current_grid = step
    end
  end

  def playback
    history.each_with_index do |snapshot, step|
      visualize(snapshot, step)
    end
  end

  private

  def behaviors
    @behaviors ||= [FoodBehavior.new, CampBehavior.new, MoldBehavior.new]
  end

  def visualize(grid, step)
    xs, ys, values = [], [], []

    grid.each do |(x, y), state|
      xs << x
      ys << y
      values << [state[:food], state[:mold], state[:camp]]
    end

    plot(xs, ys, values, step)
  end

  def plot(xs, ys, values, step)
    normalized_values = normalize_values(values)

    Rubyplot::Scatter.new do |plot|
      plot.data :Values, xs, ys, normalized_values
      plot.title = "Step #{step}: Food, Mold, and Signal"
      plot.x_label = 'X'
      plot.y_label = 'Y'
      plot.legend = true
    end
  end

  def normalize_values(values)
    max_values = values.transpose.map(&:max)
    values.map { |v| v.zip(max_values).map { |val, max| val.to_f / (max || 1) } }
  end

  def initialize_grid
    grid = Hash.new { |hash, key| hash[key] = { mold: 0, food: 0, camp: 0, refractory: 0 } }
    grid[[0, 0]] = { mold: CONFIG[:initial_cells], food: CONFIG[:food_capacity], camp: 0, refractory: 0 }
    grid
  end
end

# Main simulation loop
def main
  simulation = Simulation.new
  simulation.run(50)  # Run the simulation for 50 steps
  simulation.playback
end

main
