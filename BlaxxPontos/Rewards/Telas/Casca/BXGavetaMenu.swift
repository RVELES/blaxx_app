//
//  BXGavetaMenu.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Casca)
//
//  Conteúdo das gavetas (blaxx-nav.js, fotos web 91/92):
//  - logado (pela esquerda): CONTA Início, Carteira, Extrato, Cartão BlaXx, Perfil · PONTOS Comprar pontos,
//    Enviar pontos, Receber pontos, Resgatar benefícios, Convidar amigos (D06) · DESCOBRIR Parceiros,
//    Campanhas (D04) · AJUDA Central de ajuda, Perguntas frequentes, Abrir chamado · [Sair] com confirmação;
//  - visitante (pela direita): [Criar conta] [Entrar] · CONHEÇA Comprar pontos, Como funciona, Parceiros,
//    Regulamento · AJUDA Central de ajuda, Perguntas frequentes, Fale conosco.
//  Item atual: fundo tinta com texto superfície.
//

import SwiftUI

struct BXGavetaMenuLogado: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @State private var confirmarSair = false

    private var atual: BXDestino { nav.pilha(nav.aba).last ?? nav.raiz(da: nav.aba) }

    var body: some View {
        Group {
            BXGavetaGrupo("Conta")
            item("Início", .inicio)
            item("Carteira", .carteira)
            item("Extrato", .extrato(.tudo))
            item("Cartão BlaXx", .cartaoBlaxx)
            item("Perfil", .perfil)
            BXGavetaGrupo("Pontos")
            if BXRecursos.compraNoApp { item("Comprar pontos", .comprar(pacote: nil)) }
            item("Enviar pontos", .enviar(para: nil))
            item("Receber pontos", .receber)
            item("Resgatar benefícios", .resgates(.catalogo))
            if BXRecursos.convidarAmigos { item("Convidar amigos", .convidar) }
            BXGavetaGrupo("Descobrir")
            item("Parceiros", .parceiros(busca: nil))
            if BXRecursos.campanhas { item("Campanhas", .campanhas) }
            BXGavetaGrupo("Ajuda")
            item("Central de ajuda", .ajuda)
            item("Perguntas frequentes", .faq)
            // Não há destino próprio para o chamado: a Central de ajuda (G5) abre o chamado por e-mail.
            BXGavetaItem("Abrir chamado") { nav.ir(.ajuda) }
            BXBotao("Sair", estilo: .primario, carregando: sessao.saindo) { confirmarSair = true }
                .frame(minHeight: 50)
                .padding(.top, 18)
                .padding(.horizontal, 2)
                .confirmationDialog("Sair da sua conta?", isPresented: $confirmarSair, titleVisibility: .visible) {
                    Button("Sair", role: .destructive) {
                        Task {
                            await sessao.sair()
                            BXHaptica.tocar(.sucesso)
                        }
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Você vai precisar entrar de novo para ver seus pontos.")
                }
        }
    }

    private func item(_ titulo: String, _ destino: BXDestino) -> some View {
        BXGavetaItem(titulo, atual: BXRoteador.mesmoLugar(atual, destino)) {
            if BXRoteador.mesmoLugar(atual, destino) { nav.fecharGaveta() } else { nav.ir(destino) }
        }
    }
}

struct BXGavetaMenuVisitante: View {
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXFluxoAcesso.self) private var fluxo

    var body: some View {
        Group {
            VStack(spacing: 12) {
                BXBotao("Criar conta", estilo: .primario) { nav.ir(.cadastro) }
                BXBotao("Entrar", estilo: .secundario) { nav.ir(.entrar) }
            }
            .padding(.horizontal, 2)
            .padding(.top, 4)
            BXGavetaGrupo("Conheça")
            if BXRecursos.compraNoApp {
                BXGavetaItem("Comprar pontos") { nav.pedirEntrada(depois: .comprar(pacote: nil)) }
            }
            BXGavetaItem("Como funciona") {
                nav.fecharGaveta()
                nav.voltarParaRaiz()
                fluxo.rolarBoasVindasPara = "rota"
            }
            BXGavetaItem("Parceiros") { nav.ir(.parceiros(busca: nil)) }
            BXGavetaItem("Regulamento") {
                nav.fecharGaveta()
                nav.abrirSite("regulamento.html")
            }
            BXGavetaGrupo("Ajuda")
            BXGavetaItem("Central de ajuda") { nav.ir(.ajuda) }
            BXGavetaItem("Perguntas frequentes") { nav.ir(.faq) }
            BXGavetaItem("Fale conosco") {
                nav.fecharGaveta()
                nav.abrirSite("contato.html")
            }
        }
    }
}
