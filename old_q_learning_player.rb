require 'ruby-fann'

class QLearningPlayer
  attr_accessor :x, :y, :game

  def initialize
    @x = 0
    @y = 0
    @actions = [:left, :right, :up, :down]
    @first_run = true

    @discount = 0.7
    @epsilon = 0.1
    @max_epsilon = 0.9
    @epsilon_increase_factor = 1000.0

    @replay_memory_size = 100
    @replay_memory_pointer = 0
    @replay_memory = []
    @replay_batch_size = 50

    @runs = 0

    @r = Random.new
  end

  def initialize_q_neural_network
    # Setup model
    # Input is the size of the map
    # Output is the size of all actions
    @q_nn_model = RubyFann::Standard.new(
                  num_inputs: @game.map_size_x*@game.map_size_y + @actions.length,
                  hidden_neurons: [ (@game.map_size_x*@game.map_size_y+@actions.length) ],
                  num_outputs: 1 )

    @q_nn_model.set_learning_rate(0.1)

    @q_nn_model.set_activation_function_hidden(:sigmoid_symmetric)
    @q_nn_model.set_activation_function_output(:sigmoid_symmetric)

  end

  def get_input
    # Pause to make sure humans can follow along
    sleep 0.05 + 0.01*(@runs/500.0)
    @runs += 1

    if @first_run
      # If this is first run initialize the Q-neural network
      initialize_q_neural_network
      @first_run = false
    else
      # If this is not the first run
      # Evaluate what happened on last action and update Q table
      # Calculate reward
      r = 0 # default is 0
      if !@game.new_game and @old_score < @game.score
        r = 1 # reward is 1 if our score increased
      elsif !@game.new_game and @old_score > @game.score
        r = -1 # reward is -1 if our score decreased
      elsif !@game.new_game
        r = -0.1
      end

      # If replay memory is not full add old state, reward and new state to replay memory
      if @replay_memory_pointer < @replay_memory_size
        # Add to memory
        @replay_memory[@replay_memory_pointer] = {old_q_value_for_action: @old_q_value_for_action, reward: r, old_input_state: @old_input_state, input_state: input_state}
        # Increment memory pointer
        @replay_memory_pointer += 1
      else
        # If memory is full randomly samply a batch of actions from the memory and train network with these actions
        @batch = @replay_memory.sample(@replay_batch_size)

        x_data = []
        y_data []

        # For each batch calculate new
        @batch.each do |m|
          input_state = m[:input_state]
          # To get entire q table row of the current state run the network once for every posible action
          q_table_row = []
          @actions.length.times do |a|
            # Create neural network input vector for this action
            input_state_action = input_state.clone
            # Set a 1 in the action location of the input vector
            input_state_action[(@game.map_size_x*@game.map_size_y) + a] = 1
            # Run the network for this action and get q table row entry
            q_table_row[a] = @q_nn_model.run(input_state_action).first
          end

          # Update the old q value
          updated_q_value = m[:reward] + @discount * q_table_row.max

          # Add to training set
          x_data.push(m[:old_input_state])
          y_data.push([updated_q_value])
        end

        # traing network 

      end

      # Run prediction on the outcome state to get q_table_row for this state
      # Create network input vector represeting the current state after action was taken
      # Set input to network map_size_x * map_size_y vector + @actions.length
      input_state = Array.new(@game.map_size_x*@game.map_size_y + @actions.length, 0)
      #Set a 1 on the player position
      input_state[@x + (@game.map_size_x*@y)] = 1

      # To get the entire q table row of the current state run the network once for every posible action
      q_table_row = []
      @actions.length.times do |a|
        # Create neural network input vector for this action
        input_state_action = input_state.clone
        # Set a 1 in the action location of the input vector
        input_state_action[(@game.map_size_x*@game.map_size_y) + a] = 1
        # Run the network for this action and get q table row entry
        q_table_row[a] = @q_nn_model.run(input_state_action).first
      end

      puts "#{q_table_row}"
      # Update the old q value
      @old_q_value_for_action = r + @discount * q_table_row.max
      puts @old_q_value_for_action

      # Train the neural network with the updated q-table entry
      @q_nn_model.train(@old_input_state, [@old_q_value_for_action])

    end

    # Capture current state and score
    # Set input to network map_size_x * map_size_y vector with a 1 on the player position
    input_state = Array.new(@game.map_size_x*@game.map_size_y + @actions.length, 0)
    input_state[@x + (@game.map_size_x*@y)] = 1

    # To get the entire q table row of the current state run the network once for every posible action
    q_table_row = []
    @actions.length.times do |a|
      # Create neural network input vector for this action
      input_state_action = input_state.clone
      # Set a 1 in the action location of the input vector
      input_state_action[(@game.map_size_x*@game.map_size_y) + a] = 1
      # Run the network for this action and get q table row entry
      q_table_row[a] = @q_nn_model.run(input_state_action).first
    end

    # Chose action based on Q value estimates for state
    # If a random number is higher than epsilon we take a random action
    # We will slowly increase @epsilon based on runs to a maximum of 0.9
    epsilon_run_factor = (@runs/@epsilon_increase_factor) > (@max_epsilon-@epsilon) ? (@max_epsilon-@epsilon) : (@runs/@epsilon_increase_factor)
    if @r.rand > (@epsilon + epsilon_run_factor)
      # Select random action
      @action_taken_index = @r.rand(@actions.length)
      puts "RANDOM e = #{@epsilon + epsilon_run_factor}"
    else
      # Select action with highest posible reward
      @action_taken_index = q_table_row.each_with_index.max[1]
    end

    # Save current state, score and q table row
    @old_score = @game.score

    # Set action taken in input state before storing it
    input_state[(@game.map_size_x*@game.map_size_y) + @action_taken_index] = 1
    @old_input_state = input_state
    @old_q_value_for_action = q_table_row[@action_taken_index]

    # Take action
    return @actions[@action_taken_index]
  end


  def print_table
    @q_table.length.times do |i|
      puts @q_table[i].to_s
    end
  end

end