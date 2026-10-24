//
//  BXVoucherTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Detalhe do voucher (`GET /vouchers/<id>`), no lugar do `detalhe-voucher.html` fixo do web (fotos 39):
//  código grande em mono + copiar, status, validade, benefício. Sem QR: nenhum parceiro lê esse código
//  por câmera hoje, e um QR sugeriria uma integração que não existe.
//

import SwiftUI

struct BXVoucherTela: View {
    let id: String

    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    @State private var carga: BXCarga<BXVoucher> = .carregando

    var body: some View {
        ScrollView {
            BXColunaDescobrir {
                BXFarelo(itens: [("Resgates", { nav.ir(.resgates(.catalogo)) }),
                                 ("Meus resgates", { nav.ir(.resgates(.meusResgates)) }),
                                 (carga.valor?.nomeBeneficio ?? "Voucher", nil)])
                    .padding(.bottom, 20)
                switch carga {
                case .ocioso, .carregando:
                    BXEsqueleto(.bloco(altura: 420))
                case .erro(let e) where e.tipo == .naoEncontrado:
                    BXEstadoVazio(icone: .voucher, titulo: "Voucher não encontrado.",
                                  texto: "Ele não está na sua conta ou o endereço mudou.",
                                  acao: (titulo: "Ver meus resgates", executar: { nav.ir(.resgates(.meusResgates)) }))
                case .erro(let e):
                    BXEstadoErro(e) { await carregar() }
                case .vazio:
                    EmptyView()
                case .pronto(let v):
                    conteudo(v)
                }
            }
        }
        .background(BXCor.chao, in: Rectangle())
        .refreshable { await carregar() }
        .task { if carga.valor == nil { await carregar() } }
        .modifier(BXZoomDestino(id: "voucher-\(id)"))
    }

    @ViewBuilder private func conteudo(_ v: BXVoucher) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                BXStatusVoucherVista(status: v.status)
                Text(v.nomeBeneficio).bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(textoStatus(v)).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
            BXRecibo(cabeca: "Voucher") {
                BXReciboTracejo()
                VStack(alignment: .leading, spacing: 10) {
                    Text("CÓDIGO").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    Text(v.codigo.isEmpty ? "—" : v.codigo)
                        .bxFonte(.saldoMono)
                        .foregroundStyle(v.status == .ativo ? BXCor.tinta : BXCor.cinza)
                        .strikethrough(v.status != .ativo, color: BXCor.cinza)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .textSelection(.enabled)
                        .accessibilityLabel("Código \(v.codigo.map { String($0) }.joined(separator: " "))")
                    if v.status == .ativo && !v.codigo.isEmpty {
                        BXBotao("Copiar código", estilo: .secundario, icone: .documento) {
                            BXCopiar.copiar(v.codigo, aviso: "Código copiado.", toast: toast)
                        }
                    }
                }
                BXReciboTracejo()
                BXReciboLinha("Benefício", v.nomeBeneficio)
                BXReciboLinha("Status", BXStatusVoucherVista.texto(v.status).lowercased())
                if let c = v.criadoEm { BXReciboLinha("Resgatado em", BXFormato.data(c)) }
                if let u = v.usadoEm { BXReciboLinha("Usado em", BXFormato.data(u)) }
                if let e = v.expiraEm { BXReciboLinha(v.status == .expirado ? "Venceu em" : "Válido até", BXFormato.data(e)) }
                BXReciboFaixa("Pontos usados", "\(BXFormato.pontos(v.pontosGastos)) pts")
                BXReciboNota("Apresente o código ao parceiro conforme as condições do benefício. Dúvidas? Fale com o suporte pela Central de ajuda.")
                BXReciboVia()
            }
            VStack(spacing: 12) {
                if let bid = v.beneficioID {
                    BXBotao("Ver benefício", estilo: .secundario) { nav.ir(.beneficio(id: bid)) }
                }
                BXBotao("Ver meus resgates", estilo: .secundario) { nav.ir(.resgates(.meusResgates)) }
                BXLinkSeta("Central de ajuda") { nav.ir(.ajuda) }
            }
        }
    }

    private func textoStatus(_ v: BXVoucher) -> String {
        switch v.status {
        case .ativo: return v.expiraEm.map { "Pronto para usar até \(BXFormato.data($0))." } ?? "Pronto para usar."
        case .usado: return "Este voucher já foi usado."
        case .expirado: return "Este voucher venceu e não pode mais ser usado."
        case .desconhecido: return "A situação deste voucher está em análise."
        }
    }

    private func carregar() async {
        do {
            carga = .pronto(try await BXAPI.shared.voucher(id: id))
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if case .pronto = carga { return }
            carga = .erro(BXErro.de(error))
        }
    }
}
