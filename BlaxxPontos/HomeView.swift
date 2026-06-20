//
//  HomeView.swift
//  BlaxxPontos
//
//  Home pública (pré-login) — paridade com a landing web/Windows.
//  Marketing estilo programa de pontos com a identidade Blaxx; o botão
//  "Entrar" leva à LoginView, onde de fato é necessário se credenciar.
//

import SwiftUI

struct HomeView: View {
    /// Chamado quando o usuário decide entrar/criar conta → ContentView abre a LoginView.
    var onEnter: () -> Void

    private let ways: [(String, String, String)] = [
        ("cart.fill", "Compras nos parceiros", "Acumule a cada real gasto nas marcas parceiras, online ou na loja."),
        ("target", "Campanhas e missões", "Participe de desafios e ganhe pontos extras ao completar metas."),
        ("person.2.fill", "Indique amigos", "Convide pessoas e ganhe pontos na primeira compra delas."),
        ("star.fill", "Suba de plano", "Plus, Prime e Black multiplicam seu acúmulo com bônus progressivo.")
    ]

    private let catalog: [(String, String)] = [
        ("Cashback no Pix", "Receba o valor direto na conta."),
        ("Vouchers", "Vale-compras das principais marcas."),
        ("Milhas", "Transfira para programas aéreos."),
        ("Descontos", "Abata pontos na próxima compra."),
        ("Produtos", "Troque por itens do catálogo.")
    ]

    private let faq: [(String, String)] = [
        ("Quanto custa participar?", "Nada. Criar conta e acumular pontos é totalmente gratuito, sem mensalidade."),
        ("Quanto vale cada ponto?", "Cada ponto equivale a R$ 0,09 no resgate, exibido na hora da troca."),
        ("Os pontos expiram?", "Têm validade longa e você é avisado com antecedência antes de qualquer expiração."),
        ("Como recebo o cashback?", "Direto no seu Pix, em poucos minutos após confirmar o resgate.")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            BlaxxColor.appBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    globalNetwork
                    partnersStrip
                    howItWorks
                    waysToEarn
                    tiersSection
                    catalogSection
                    statsBand
                    faqSection
                    finalCTA
                    footer
                }
            }

            header
        }
    }

    // MARK: - Global Network (mapa-múndi + hotéis)

    private let pinOffsets: [CGSize] = [
        CGSize(width: -70, height: -30), CGSize(width: 60, height: -55),
        CGSize(width: 80, height: 35), CGSize(width: -15, height: 65),
        CGSize(width: -45, height: -60),
    ]
    private let hotels: [(String, String, String, Color)] = [
        ("M", "Marriott Bonvoy", "8.500+ hotéis · 139 países", Color(red: 0.48, green: 0.12, blue: 0.23)),
        ("H", "Hilton Honors", "7.000+ hotéis · 122 países", Color(red: 0.06, green: 0.30, blue: 0.59)),
        ("A", "Accor ALL", "5.500+ hotéis · 110 países", Color(red: 0.78, green: 0.06, blue: 0.18)),
        ("I", "IHG One Rewards", "6.000+ hotéis · 100 países", Color(red: 0.04, green: 0.24, blue: 0.18)),
        ("Y", "World of Hyatt", "1.300+ hotéis · 75 países", Color(red: 0.48, green: 0.36, blue: 1.0)),
        ("ML", "Meliá Rewards", "380+ hotéis · 40 países", Color(red: 0.12, green: 0.44, blue: 0.36)),
    ]

    private var globalNetwork: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("BLAXX GLOBAL NETWORK™").font(.system(size: 12, weight: .black)).tracking(1.2)
                    .foregroundStyle(BlaxxColor.limeDark)
                Text("Seus pontos viajam o mundo.")
                    .font(BlaxxFont.display(30, weight: .black)).foregroundStyle(BlaxxColor.black)
                    .multilineTextAlignment(.center)
                Text("Destinos, companhias aéreas e hotéis premium onde seus pontos viram estadia, voo e experiência.")
                    .font(.system(size: 15)).foregroundStyle(BlaxxColor.gray600)
                    .multilineTextAlignment(.center).frame(maxWidth: 520)
            }
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(red: 0.086, green: 0.125, blue: 0.165), Color(red: 0.027, green: 0.043, blue: 0.059)], center: UnitPoint(x: 0.42, y: 0.38), startRadius: 5, endRadius: 170))
                    .overlay(Circle().stroke(BlaxxColor.lime.opacity(0.25), lineWidth: 1))
                Ellipse().stroke(Color.white.opacity(0.12), lineWidth: 1).frame(width: 100, height: 300)
                Ellipse().stroke(Color.white.opacity(0.09), lineWidth: 1).frame(width: 200, height: 300)
                Rectangle().fill(Color.white.opacity(0.1)).frame(width: 300, height: 1)
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(BlaxxColor.lime).frame(width: 8, height: 8)
                        .shadow(color: BlaxxColor.lime.opacity(0.6), radius: 6).offset(pinOffsets[i])
                }
            }
            .frame(width: 300, height: 300).clipShape(Circle())

            VStack(spacing: 0) {
                HStack {
                    Text("Hotéis que aceitam pontos").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                    Text("rede em expansão").font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(BlaxxColor.lime.opacity(0.16))).foregroundStyle(BlaxxColor.lime)
                }.padding(.bottom, 8)
                ForEach(hotels, id: \.1) { h in
                    HStack(spacing: 12) {
                        Text(h.0).font(.system(size: 14, weight: .black)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(RoundedRectangle(cornerRadius: 12).fill(h.3))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.1).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                            Text(h.2).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Text("Estadia").font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(BlaxxColor.lime)).foregroundStyle(BlaxxColor.black)
                    }.padding(.vertical, 10)
                    if h.1 != hotels.last?.1 { Divider().overlay(Color.white.opacity(0.1)) }
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24).fill(LinearGradient(colors: [Color(red: 0.024, green: 0.031, blue: 0.039), Color(red: 0.063, green: 0.086, blue: 0.114)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        }
        .padding(.horizontal, 24).padding(.vertical, 40)
    }

    // MARK: - Tiers (com BlaXx VIP)

    private var tiers: [(Color, String, String, String, Bool)] {
        [
            (Color(red: 0.80, green: 0.50, blue: 0.20), "Bronze", "0+ pts", "Acesso ao programa, catálogo e PIX.", false),
            (Color(red: 0.60, green: 0.63, blue: 0.65), "Prata", "5.000+ pts", "Ofertas exclusivas + atendimento prioritário.", false),
            (Color(red: 0.83, green: 0.69, blue: 0.22), "Ouro", "20.000+ pts", "Bônus em campanhas + benefícios premium.", false),
            (Color(red: 0.04, green: 0.04, blue: 0.05), "Black", "50.000+ pts", "Experiências Black e limites ampliados.", false),
            (BlaxxColor.lime, "BlaXx VIP", "Por convite", "Compras ilimitadas, exchange preferencial e concierge.", true),
        ]
    }

    private var tiersSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("NÍVEIS BLAXX").font(.system(size: 12, weight: .black)).tracking(1.2).foregroundStyle(BlaxxColor.limeDark)
                Text("Quanto mais você usa, mais alto você chega.")
                    .font(BlaxxFont.display(28, weight: .black)).foregroundStyle(BlaxxColor.black).multilineTextAlignment(.center)
                Text("No topo, o BlaXx VIP — exclusivo, apenas por convite.")
                    .font(.system(size: 15)).foregroundStyle(BlaxxColor.gray600).multilineTextAlignment(.center)
            }
            ForEach(tiers, id: \.1) { t in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 9).fill(t.0).frame(width: 30, height: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.1).font(.system(size: 16, weight: .bold)).foregroundStyle(t.4 ? BlaxxColor.lime : BlaxxColor.black)
                        Text(t.3).font(.system(size: 12)).foregroundStyle(t.4 ? Color(white: 0.8) : BlaxxColor.gray600)
                    }
                    Spacer()
                    Text(t.2).font(.system(size: 12, weight: .semibold)).foregroundStyle(t.4 ? BlaxxColor.lime : BlaxxColor.gray400)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18).fill(
                        t.4 ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.04, green: 0.04, blue: 0.04), Color(red: 0.086, green: 0.094, blue: 0.11)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(BlaxxColor.white))
                )
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(t.4 ? BlaxxColor.lime.opacity(0.4) : BlaxxColor.border, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 40)
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            BlaxxWordmark(size: 26, tone: .dark)
            Spacer()
            Button("Entrar", action: onEnter)
                .buttonStyle(GhostButtonStyle())
            Button("Criar conta", action: onEnter)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .bottom)
    }

    // MARK: - Hero
    private var hero: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                Eyebrow(text: "Pontos · Pix · Vantagens")
                (Text("Compre. Ganhe. ") + Text("Troque.").foregroundColor(BlaxxColor.limeDark) + Text(" Envie."))
                    .font(BlaxxFont.display(40, weight: .black))
                    .foregroundStyle(BlaxxColor.black)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A plataforma que transforma seus pontos em Pix na hora, milhas, diárias de hotel e salas VIP — com os melhores parceiros do Brasil e do mundo.")
                    .font(.system(size: 16))
                    .foregroundStyle(BlaxxColor.gray600)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                HStack(spacing: 12) {
                    Button("Criar conta e ganhar 500 pts →", action: onEnter)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Já tenho conta · Entrar", action: onEnter)
                        .buttonStyle(GhostButtonStyle())
                }
                Text("★★★★★  Mais de 1 milhão de resgates realizados")
                    .font(.system(size: 13))
                    .foregroundStyle(BlaxxColor.gray400)
            }

            walletMock
        }
        .padding(.top, 96)
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }

    private var walletMock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SALDO BLAXX")
                    .font(BlaxxFont.mono(11)).tracking(1.4)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("PLANO PLUS")
                    .font(BlaxxFont.mono(10)).tracking(1.0)
                    .foregroundStyle(BlaxxColor.black)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(BlaxxColor.lime))
            }
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("32.480").font(BlaxxFont.display(48, weight: .black))
                    .foregroundStyle(BlaxxColor.lime)
                Text("pts").font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.top, 14)
            Text("≈ R$ 324,80 em resgates")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 0) {
                walletStat("+1.250", "este mês")
                walletStat("4", "vouchers")
                walletStat("2", "campanhas")
            }
            .padding(.vertical, 16)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.1)), alignment: .top)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.1)), alignment: .bottom)
            .padding(.vertical, 16)

            Button("Resgatar pontos →", action: onEnter)
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 28).fill(BlaxxColor.black))
        .frame(maxWidth: 420)
    }

    private func walletStat(_ n: String, _ k: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(n).font(BlaxxFont.display(19, weight: .bold)).foregroundStyle(.white)
            Text(k.uppercased()).font(BlaxxFont.mono(10)).tracking(0.8)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Partners
    private var partnersStrip: some View {
        VStack(spacing: 14) {
            Text("ACUMULE COMPRANDO EM CENTENAS DE MARCAS")
                .font(BlaxxFont.mono(11)).tracking(1.4)
                .foregroundStyle(BlaxxColor.gray400)
            FlowRow(spacing: 28, items: ["SuperMix","FarmaPlus","PostoVia","VocJá","ModaUrban","TechStore","CaféDoz","PetCare","EduMais","StreamGo"]) { brand in
                Text(brand)
                    .font(BlaxxFont.display(18, weight: .bold))
                    .foregroundStyle(BlaxxColor.gray400)
            }
        }
        .padding(.vertical, 26).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(BlaxxColor.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .top)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .bottom)
    }

    // MARK: - How it works
    private var howItWorks: some View {
        VStack(spacing: 36) {
            sectionHead(eyebrow: "Como funciona",
                        title: "Três passos para começar a ganhar",
                        sub: "Sem complicação. Crie sua conta, compre normalmente e veja os pontos caírem.")
            VStack(spacing: 16) {
                stepCard("01", "Crie sua conta grátis", "Cadastro em menos de 1 minuto com seu e-mail. Ganhe 500 pontos de boas-vindas.")
                stepCard("02", "Compre nos parceiros", "A cada compra nas marcas parceiras você acumula pontos automaticamente na carteira.")
                stepCard("03", "Troque pelo que quiser", "Resgate por vouchers, milhas, descontos ou receba o valor de volta no seu Pix.")
            }
            .frame(maxWidth: 720)
        }
        .padding(.vertical, 64).padding(.horizontal, 24)
    }

    private func stepCard(_ num: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(num).font(BlaxxFont.mono(13)).foregroundStyle(BlaxxColor.limeDark)
            Text(title).font(BlaxxFont.display(20, weight: .bold)).foregroundStyle(BlaxxColor.black)
            Text(body).font(.system(size: 14.5)).foregroundStyle(BlaxxColor.gray600)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(26)
        .background(RoundedRectangle(cornerRadius: 20).fill(BlaxxColor.white))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(BlaxxColor.border, lineWidth: 1))
    }

    // MARK: - Ways to earn
    private var waysToEarn: some View {
        VStack(spacing: 36) {
            sectionHead(eyebrow: "Juntar pontos",
                        title: "Acelere de 4 formas",
                        sub: "Quanto mais você usa o ecossistema Blaxx, mais rápido seus pontos crescem.")
            VStack(spacing: 16) {
                ForEach(ways, id: \.0) { icon, title, body in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(BlaxxColor.limeDark)
                            .frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(BlaxxColor.limeLight))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(BlaxxFont.display(17, weight: .bold)).foregroundStyle(BlaxxColor.black)
                            Text(body).font(.system(size: 14)).foregroundStyle(BlaxxColor.gray600)
                        }
                        Spacer()
                    }
                    .padding(22)
                    .background(RoundedRectangle(cornerRadius: 20).fill(BlaxxColor.appBg))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(BlaxxColor.border, lineWidth: 1))
                }
            }
            .frame(maxWidth: 720)
        }
        .padding(.vertical, 64).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(BlaxxColor.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .top)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .bottom)
    }

    // MARK: - Catalog
    private var catalogSection: some View {
        VStack(spacing: 36) {
            sectionHead(eyebrow: "Trocar pontos",
                        title: "Resgate do seu jeito",
                        sub: "Seus pontos, suas regras. Escolha entre dezenas de opções de resgate.")
            VStack(spacing: 14) {
                ForEach(catalog, id: \.0) { title, body in
                    VStack(spacing: 4) {
                        Text(title).font(BlaxxFont.display(16, weight: .bold)).foregroundStyle(BlaxxColor.black)
                        Text(body).font(.system(size: 13)).foregroundStyle(BlaxxColor.gray600)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20).padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(BlaxxColor.white))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(BlaxxColor.border, lineWidth: 1))
                }
            }
            .frame(maxWidth: 520)
        }
        .padding(.vertical, 64).padding(.horizontal, 24)
    }

    // MARK: - Stats band
    private var statsBand: some View {
        VStack(spacing: 28) {
            statRow("1M+", "resgates realizados")
            statRow("500+", "marcas parceiras")
            statRow("R$ 0,09", "por ponto resgatado")
            statRow("100%", "gratuito, sem mensalidade")
        }
        .padding(40)
        .frame(maxWidth: 720)
        .background(RoundedRectangle(cornerRadius: 28).fill(BlaxxColor.black))
        .padding(.vertical, 56).padding(.horizontal, 24)
    }

    private func statRow(_ n: String, _ k: String) -> some View {
        VStack(spacing: 6) {
            Text(n).font(BlaxxFont.display(40, weight: .black)).foregroundStyle(BlaxxColor.lime)
            Text(k).font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - FAQ
    private var faqSection: some View {
        VStack(spacing: 36) {
            sectionHead(eyebrow: "Dúvidas", title: "Perguntas frequentes", sub: nil)
            VStack(spacing: 0) {
                ForEach(faq, id: \.0) { q, a in
                    DisclosureGroup {
                        Text(a).font(.system(size: 14.5)).foregroundStyle(BlaxxColor.gray600)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                    } label: {
                        Text(q).font(BlaxxFont.display(17, weight: .bold)).foregroundStyle(BlaxxColor.black)
                    }
                    .tint(BlaxxColor.limeDark)
                    .padding(.vertical, 18)
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .bottom)
                }
            }
            .frame(maxWidth: 640)
        }
        .padding(.vertical, 64).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(BlaxxColor.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .top)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(BlaxxColor.border), alignment: .bottom)
    }

    // MARK: - Final CTA
    private var finalCTA: some View {
        VStack(spacing: 14) {
            Text("Comece a juntar pontos hoje")
                .font(BlaxxFont.display(32, weight: .black))
                .foregroundStyle(.white).multilineTextAlignment(.center)
            Text("Crie sua conta grátis e ganhe 500 pontos de boas-vindas. Leva menos de um minuto.")
                .font(.system(size: 16)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button("Criar conta grátis →", action: onEnter)
                    .buttonStyle(PrimaryButtonStyle())
                Button("Entrar", action: onEnter)
                    .buttonStyle(GhostButtonStyle(onDark: true))
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 56).padding(.horizontal, 36)
        .frame(maxWidth: 720)
        .background(RoundedRectangle(cornerRadius: 28).fill(BlaxxColor.black))
        .padding(.vertical, 56).padding(.horizontal, 24)
    }

    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 12) {
            BlaxxWordmark(size: 26, tone: .light)
            Text("Plataforma de pontos que transforma suas compras do dia a dia em recompensas de verdade.")
                .font(.system(size: 13.5)).foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center).frame(maxWidth: 360)
            Text("© 2026 BlaXx · FEITO NO BRASIL")
                .font(BlaxxFont.mono(11)).foregroundStyle(.white.opacity(0.4))
                .padding(.top, 14)
        }
        .padding(.vertical, 48).padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(BlaxxColor.black)
    }

    // MARK: - Helpers
    private func sectionHead(eyebrow: String, title: String, sub: String?) -> some View {
        VStack(spacing: 10) {
            Eyebrow(text: eyebrow)
            Text(title).font(BlaxxFont.display(30, weight: .black))
                .foregroundStyle(BlaxxColor.black).multilineTextAlignment(.center)
            if let sub {
                Text(sub).font(.system(size: 16)).foregroundStyle(BlaxxColor.gray600)
                    .multilineTextAlignment(.center).frame(maxWidth: 520)
            }
        }
    }
}

/// Layout simples que quebra os itens em linhas (wrap) — usado na faixa de parceiros.
private struct FlowRow<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let spacing: CGFloat
    let items: Data
    @ViewBuilder let content: (Data.Element) -> Content

    var body: some View {
        // Em telas estreitas as marcas quebram naturalmente com este wrapping manual.
        VStack(spacing: 12) {
            let rows = chunked(Array(items), into: 5)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { item in content(item) }
                }
            }
        }
    }

    private func chunked(_ arr: [Data.Element], into size: Int) -> [[Data.Element]] {
        stride(from: 0, to: arr.count, by: size).map { Array(arr[$0..<min($0 + size, arr.count)]) }
    }
}

#Preview("Home") {
    HomeView(onEnter: {})
}
