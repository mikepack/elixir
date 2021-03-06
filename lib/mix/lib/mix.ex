defmodule Mix do
  @moduledoc ~S"""
  Mix is a build tool that provides tasks for creating, compiling,
  testing Elixir projects, as well as handle dependencies, and more.

  ## Mix.Project

  The foundation of Mix is a project. A project can be defined by
  by using the `Mix.Project` in a module, usually place in a file
  named `mix.exs`:

      defmodule MyApp.Mixfile do
        def project do
          [app: :my_app,
           version: "1.0.0"]
        end
      end

  The `project/0` function is where the project information is defined
  and it allows developers to configure many tasks.

  After the project above is defined, there are many tasks one can
  run directly from the command line:

    * `mix compile` - compiles the current project
    * `mix test` - runs tests for the given project
    * `mix run` - runs a particular command inside the project

  Each task has its own options and sometimes specific configuration
  to be defined in the `project/0` function. You can use `mix help`
  to list all available tasks and `mix help NAME` to show help for
  a particular task.

  The best way to get started with your first project is by calling
  `mix new my_project` from the command line.

  ## Mix.Task

  Tasks are what make Mix extensible.

  Any project can extend Mix behaviour by adding their own tasks. For
  example, you can add the task below inside your project and it will
  be available to everyone that uses your project:

      defmodule Mix.Tasks.Hello do
        use Mix.Task

        def run(_) do
          Mix.shell.info "hello"
        end
      end

  Now they can invoke it with `mix run hello`.

  ## Dependencies

  Another important feature in Mix is that it is able to manage your
  dependencies and integrates nicely with [the Hex package manager](http://hex.pm).

  In order to use dependencies, you just need to add a `:deps` key
  to your project configuration. We often extract the dependencies
  listing to its own functions:

      defmodule MyApp.Mixfile do
        def project do
          [app: :my_app,
           version: "1.0.0",
           deps: deps]
        end

        defp deps do
          [{:ecto, "~> 0.3.0"},
           {:plug, github: "elixir-lang/plug"}]
        end
      end

  You can run `mix help deps` to learn more about dependencies in Mix.

  ## Environments

  Mix provides environments.

  Environments allow developers to prepare and organize their project
  specific to different scenarios. By default, Mix provides three
  environments:

    * `:dev` - the default environment
    * `:test` - the environment `mix test` runs on
    * `:prod` - the environment your dependencies runs on

  The environment can be changed via the command line by setting
  the `MIX_ENV` environment variable, for example:

      $ MIX_ENV=prod mix run server.exs

  ## Aliases

  Aliases are shortcut or tasks specific to the current project.

  In the `Mix.Task` section, we have defined a task that would be
  available to everyone using our project as a dependency. What if
  we wanted the task to only be available for our project? Just
  define an alias:

      defmodule MyApp.Mixfile do
        def project do
          [app: :my_app,
           version: "1.0.0",
           aliases: aliases]
        end

        defp aliases do
          [c: "compile",
           hello: &hello/1]
        end

        defp hello(_) do
          Mix.shell.info "Hello world"
        end
      end

  In the example above, we have defined two aliases. One is `mix c`
  which is a shortcut for `mix compile`. The other is named
  `mix hello`, which is the equivalent to the `Mix.Tasks.Hello`
  we have defined in the `Mix.Task` section.

  Aliases may also be a list, specifying multiple tasks to run
  at once:

      [all: [&hello/1, "deps.get --only #{Mix.env}", "compile"]]

  In the example above, we have defined an alias named `mix all`,
  that prints hello, then fetches dependencies specific to the
  current environment and compiles it.

  Arguments given to the alias will be appended to the arguments
  of the last task in the list, if the last task is a function
  they will be given as a list of strings to the function.

  Finally, aliases can also be use to augment existing tasks.
  Let's suppose you want to augment `mix clean` to clean another
  directory Mix does not know about:

      [clean: ["clean", &clean_extra/1]]

  Where `&clean_extra/1` would be a function in your `mix.exs`
  with extra clean up logic.

  Note aliases do not show up on `mix help`.
  """

  use Application

  @doc false
  def start do
    {:ok, _} = Application.ensure_all_started(:mix)
    :ok
  end

  @doc false
  def start(_type, []) do
    import Supervisor.Spec

    children = [
      worker(Mix.TasksServer, []),
      worker(Mix.ProjectStack, [])
    ]

    opts = [strategy: :one_for_one, name: Mix.Supervisor]
    stat = Supervisor.start_link(children, opts)

    if env = System.get_env("MIX_ENV") do
      env(String.to_atom env)
    end

    stat
  end

  @doc """
  Returns the mix environment.
  """
  def env do
    # env is not available on bootstrapping, so set a :dev default
    Application.get_env(:mix, :env, :dev)
  end

  @doc """
  Changes the current mix env.

  Be careful when invoking this function as any project
  configuration won't be reloaded.
  """
  def env(env) when is_atom(env) do
    Application.put_env(:mix, :env, env)
  end

  @doc """
  Returns the default compilers used by Mix.

  It can be used in your `mix.exs` to prepend or
  append new compilers to Mix:

      def project do
        [compilers: Mix.compilers ++ [:foo, :bar]]
      end

  """
  def compilers do
    [:yecc, :leex, :erlang, :elixir, :app]
  end

  @doc """
  The shell is a wrapper for doing IO.

  It contains conveniences for asking the user information,
  printing status and so forth. It is also swappable,
  allowing developers to use a test shell that simply sends the
  messages to the current process.
  """
  def shell do
    Application.get_env(:mix, :shell, Mix.Shell.IO)
  end

  @doc """
  Sets the current shell.
  """
  def shell(shell) do
    Application.put_env(:mix, :shell, shell)
  end

  @doc """
  Raises a mix error that is nicely formatted.
  """
  def raise(message) when is_binary(message) do
    Kernel.raise Mix.Error, mix: true, message: message
  end

  @doc """
  Raises a mix compatible exception.

  A mix compatible exception has a `mix` field which mix
  uses to store the project or application name which is
  automatically by the formatting tools.
  """
  def raise(exception, opts) when is_atom(exception) do
    Kernel.raise %{exception.exception(opts) | mix: true}
  end
end
