#!/usr/bin/env python3
# pip install matplotlib

import matplotlib.pyplot as plt
import numpy as np

# Configuration constants
CONFIG = {
    "grid_size": 50,
    "initial_cells": 100,
    "food_capacity": 5,
    "food_consumption_rate": 0.1,
    "camp_decay": 0.1,
    "amplification_factor": 1.5,
    "refractory_period": 5,
}


# Grid utilities for common operations
class GridUtils:
    @staticmethod
    def neighbors(coord):
        x, y = coord
        return [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]

    @staticmethod
    def prune_empty_sites(grid):
        keys_to_delete = [coord for coord, state in grid.items() if all(v == 0 for v in state.values())]
        for key in keys_to_delete:
            del grid[key]

    @staticmethod
    def expand_grid(grid):
        new_cells = []
        for coord in grid.keys():
            for neighbor in GridUtils.neighbors(coord):
                if neighbor not in grid:
                    new_cells.append(neighbor)
        for cell in new_cells:
            grid[cell] = {"mold": 0, "food": 0, "camp": 0, "refractory": 0}


# Abstract base class for behaviors
class Behavior:
    def apply(self, grid, next_grid):
        for coord, state in grid.items():
            if self.is_process_site(state):
                self.process_site(grid, next_grid, coord, state)

    def is_process_site(self, state):
        return True

    def process_site(self, grid, next_grid, coord, state):
        raise NotImplementedError("Subclasses must implement the process_site method")

    def ranked_neighbors(self, grid, coord):
        return sorted(
            GridUtils.neighbors(coord), key=lambda neighbor: (-grid[neighbor]["camp"], grid[neighbor]["mold"])
        )


# MoldBehavior: Mold redistributes based on cAMP gradients
class MoldBehavior(Behavior):

    def is_process_site(self, state):
        return state["mold"] > 0

    def process_site(self, grid, next_grid, coord, state):
        total_mold = state["mold"]
        neighbors = self.ranked_neighbors(grid, coord)

        # Distribute mold to neighbors proportionally to their cAMP levels
        total_camp = sum(grid[neighbor]["camp"] for neighbor in neighbors)
        for neighbor in neighbors:
            if total_camp > 0:
                weight = grid[neighbor]["camp"] / total_camp
            else:
                weight = 1.0 / len(neighbors)
            next_grid[neighbor]["mold"] += total_mold * weight


# FoodBehavior: Mold consumes nutrients and generates cAMP
class FoodBehavior(Behavior):

    def is_process_site(self, state):
        return state["mold"] > 0 and state["food"] >= CONFIG["food_consumption_rate"]

    def process_site(self, grid, next_grid, coord, state):
        food_consumed = CONFIG["food_consumption_rate"] * state["mold"]
        next_grid[coord]["camp"] += food_consumed * CONFIG["amplification_factor"]
        next_grid[coord]["food"] -= food_consumed


# CampBehavior: Handles cAMP propagation and decay
class CampBehavior(Behavior):
    def apply(self, grid, next_grid):
        new_camp = {}

        for coord, state in grid.items():
            camp = state["camp"] * (1 - CONFIG["camp_decay"])  # Apply decay
            for neighbor in GridUtils.neighbors(coord):
                if neighbor not in new_camp:
                    new_camp[neighbor] = 0
                new_camp[neighbor] += camp * 0.25  # Distribute equally to neighbors

        for coord, camp in new_camp.items():
            next_grid[coord]["camp"] += camp


# Simulation class orchestrates the entire simulation lifecycle
class Simulation:
    def __init__(self):
        self.current_grid = self.initialize_grid()
        self.history = []

    def step(self):
        next_grid = {coord: {"mold": 0, "food": 0, "camp": 0, "refractory": 0} for coord in self.current_grid}
        GridUtils.expand_grid(self.current_grid)

        # Apply each behavior in sequence
        for behavior in self.behaviors():
            behavior.apply(self.current_grid, next_grid)

        GridUtils.prune_empty_sites(next_grid)
        self.current_grid = next_grid

    def run(self, steps):
        for _ in range(steps):
            self.history.append(self.current_grid.copy())
            self.step()

    def playback(self):
        for step, snapshot in enumerate(self.history):
            self.visualize(snapshot, step)

    def behaviors(self):
        return [MoldBehavior(), FoodBehavior(), CampBehavior()]

    def visualize(self, grid, step):
        xs, ys, values = [], [], []

        for (x, y), state in grid.items():
            xs.append(x)
            ys.append(y)
            values.append([state["mold"], state["food"], state["camp"]])

        self.plot(xs, ys, values, step)

    def plot(self, xs, ys, values, step):
        normalized_values = self.normalize_values(values)

        plt.figure()
        plt.scatter(xs, ys, c=normalized_values, cmap="viridis")
        plt.title(f"Step {step}: Food, Mold, and Signal")
        plt.colorbar()
        plt.savefig(f"step_{step}.png")
        plt.close()

    def normalize_values(self, values):
        max_values = np.max(values, axis=0)
        return np.array(values) / (max_values + 1e-9)

    def initialize_grid(self):
        grid = {}
        initial_site = {"mold": CONFIG["initial_cells"], "food": CONFIG["food_capacity"], "camp": 0, "refractory": 0}
        grid[(0, 0)] = initial_site
        return grid


# Main simulation loop
def main():
    simulation = Simulation()
    simulation.run(50)  # Run the simulation for 50 steps
    simulation.playback()


if __name__ == "__main__":
    main()
