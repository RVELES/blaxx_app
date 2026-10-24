//
//  BXConectividade.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Faixa "Conexão instável com o servidor" (§1.7.9): aparece sem caminho de rede (NWPathMonitor) ou depois
//  de 3 falhas de rede seguidas (o `BXAPI` informa cada resposta/falha). Enquanto visível, verifica sozinha
//  a cada 30 s por até 5 min (igual ao web); "Verificar agora" chama `verificar()`.
//  A casca cria UMA instância e injeta com `.environment(_:)`; a faixa usa `mostrarFaixa` e `verificando`.
//

import Foundation
import Network
import Observation

@MainActor @Observable final class BXConectividade {
    private(set) var semCaminho = false
    private(set) var falhasSeguidas = 0
    private(set) var verificando = false

    /// A faixa offline aparece.
    var mostrarFaixa: Bool { semCaminho || falhasSeguidas >= 3 }

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var tarefaAutomatica: Task<Void, Never>?

    init(observarRede: Bool = true) {
        guard observarRede else { return }
        monitor.pathUpdateHandler = { [weak self] caminho in
            let ok = caminho.status == .satisfied
            guard let forte = self else { return }
            Task { @MainActor in forte.caminhoMudou(ok) }
        }
        monitor.start(queue: DispatchQueue(label: "bx.conectividade"))
        let observador: @MainActor @Sendable (Bool) -> Void = { [weak self] ok in self?.registrar(sucesso: ok) }
        Task { await BXAPI.shared.registrar(observadorRede: observador) }
    }

    // `deinit` não para o monitor: a instância vive o app inteiro (criada pela casca).

    /// O `BXAPI` chama a cada resposta (true) ou falha de rede (false).
    func registrar(sucesso: Bool) {
        if sucesso {
            falhasSeguidas = 0
        } else {
            falhasSeguidas += 1
        }
        atualizarAutomatico()
    }

    /// "Verificar agora": GET /health.
    func verificar() {
        guard !verificando else { return }
        verificando = true
        Task {
            let ok = await BXAPI.shared.saude()
            verificando = false
            if ok { falhasSeguidas = 0 } else { falhasSeguidas = max(falhasSeguidas, 3) }
            atualizarAutomatico()
        }
    }

    private func caminhoMudou(_ ok: Bool) {
        semCaminho = !ok
        if ok && falhasSeguidas >= 3 { verificar() }
        atualizarAutomatico()
    }

    /// Verificação a cada 30 s enquanto a faixa estiver visível, por até 5 min.
    private func atualizarAutomatico() {
        if !mostrarFaixa {
            tarefaAutomatica?.cancel()
            tarefaAutomatica = nil
            return
        }
        guard tarefaAutomatica == nil else { return }
        tarefaAutomatica = Task { [weak self] in
            let inicio = Date.now
            while !Task.isCancelled, Date.now.timeIntervalSince(inicio) < 5 * 60 {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self, self.mostrarFaixa else { break }
                if !self.semCaminho { self.verificar() }
            }
            self?.tarefaAutomatica = nil
        }
    }
}
