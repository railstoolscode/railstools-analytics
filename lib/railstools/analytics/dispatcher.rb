# frozen_string_literal: true

module Railstools
  module Analytics
    # Acumula eventos em memória e manda em lote, fora do caminho da resposta.
    #
    # POR QUE NÃO MANDAR NA HORA
    # --------------------------
    # O middleware roda DENTRO do processo do app de quem nos instalou. Uma ida HTTP por
    # requisição atendida acrescentaria dezenas de milissegundos a cada página — a forma mais
    # rápida de alguém desinstalar um agente de medição. O lote resolve: a requisição só
    # empilha em memória (microssegundos) e uma thread separada envia.
    #
    # A FILA TEM TETO, E DESCARTA O MAIS NOVO
    # ---------------------------------------
    # Se o Analytics ficar fora do ar, a fila para de crescer em `max_queue` e os eventos
    # seguintes são DESCARTADOS. Crescer sem limite mataria o app de quem nos instalou por
    # falta de memória — um agente de medição derrubando o app que ele mede é inaceitável,
    # e perder pageview de um período de indisponibilidade é o preço certo a pagar.
    #
    # SEGURANÇA COM `fork`
    # --------------------
    # Puma, Unicorn e Passenger criam os processos filhos com `fork`, e **thread não sobrevive
    # a fork**: o filho nasce com a fila cheia e sem ninguém esvaziando. Por isso a thread é
    # criada sob demanda e conferida a cada empilhada — barato, e é o que faz o agente
    # funcionar em produção em vez de só em desenvolvimento.
    class Dispatcher
      def initialize(config)
        @config = config
        @transmitter = Transmitter.new(config)
        @queue = []
        @mutex = Mutex.new
        @thread = nil
        @owner_pid = nil
        @max_queue = config.max_batch * 10
      end

      def push(event)
        @mutex.synchronize do
          return if @queue.size >= @max_queue

          @queue << event
        end

        ensure_thread
      end

      # Esvazia agora. É o que o `at_exit` chama — sem isto, os eventos do último intervalo
      # morrem junto com o processo em todo deploy.
      def flush
        lote = @mutex.synchronize { @queue.shift(@config.max_batch) }
        return true if lote.empty?

        @transmitter.deliver(lote)
      end

      def flush_all
        flush while pending?
      end

      def pending? = @mutex.synchronize { @queue.any? }

      def size = @mutex.synchronize { @queue.size }

      private

      def ensure_thread
        return if @thread&.alive? && @owner_pid == Process.pid

        @mutex.synchronize do
          return if @thread&.alive? && @owner_pid == Process.pid

          @owner_pid = Process.pid
          @thread = Thread.new { loop_forever }
          @thread.name = "railstools-analytics"
        end
      end

      def loop_forever
        loop do
          sleep @config.flush_interval
          flush
        end
      rescue StandardError => e
        # A thread morreu; a próxima empilhada recria. Registrar é o que impede o agente de
        # ficar mudo sem deixar rastro.
        Analytics.warn("a thread de envio caiu: #{e.class} #{e.message}")
      end
    end
  end
end
