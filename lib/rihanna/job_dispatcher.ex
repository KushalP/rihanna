defmodule Rihanna.JobDispatcher do
  use GenServer
  require Logger

  # maximum number of simultaneously executing tasks for this dispatcher
  @max_concurrency 50
  # milliseconds
  @poll_interval 100

  def start_link(config, opts) do
    # NOTE: It is important that a new pg session is started if the
    # JobDispatcher dies since otherwise we may leave dangling locks in the zombie
    # pg process
    db = Keyword.get(config, :db)

    {:ok, pg} = Postgrex.start_link(db)

    GenServer.start_link(__MODULE__, %{working: %{}, pg: pg}, opts)
  end

  def init(state) do
    Process.send(self(), :poll, [])
    {:ok, state}
  end

  def handle_info(:poll, state = %{working: working, pg: pg}) do
    # Fill the pipeline with as much work as we can get
    available_concurrency = @max_concurrency - Enum.count(working)

    jobs = Rihanna.Job.lock(pg, available_concurrency)

    working =
      for job <- jobs, into: working do
        task = spawn_supervised_task(job)
        {task.ref, job}
      end

    state = Map.put(state, :working, working)

    Process.send_after(self(), :poll, @poll_interval + :rand.uniform(50))

    {:noreply, state}
  end

  def handle_info({ref, result}, state = %{pg: pg, working: working}) do
    # Flush guarantees that DOWN message will be received before demonitoring
    Process.demonitor(ref, [:flush])

    {job, working} = Map.pop(working, ref)

    Rihanna.Job.mark_successful(pg, job.id)

    state = Map.put(state, :working, working)

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state = %{pg: pg, working: working}) do
    {job, working} = Map.pop(working, ref)

    Rihanna.Job.mark_failed(pg, job.id, DateTime.utc_now(), Exception.format_exit(reason))

    {:noreply, Map.put(state, :working, working)}
  end

  defp spawn_supervised_task(job) do
    Task.Supervisor.async_nolink(Rihanna.TaskSupervisor, fn ->
      {mod, fun, args} = job.mfa
      apply(mod, fun, args)
    end)
  end
end
