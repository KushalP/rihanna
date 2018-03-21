defmodule Rihanna.MixProject do
  use Mix.Project

  def project do
    [
      app: :rihanna,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 2.2.9"},
      {:postgrex, "~> 0.13.3"},
      {:jason, "~> 1.0.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package() do
    [
      description: "Rihanna is a database-backed job queue.",
      licenses: ["MIT"],
      maintainers: ["sampdavies@gmail.com"],
      links: %{}
    ]
  end
end
