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

    // Parceiros com pontos acesos no globo, como os chips da legenda na web.
    // "blaxx" são as cidades-âncora da marca: ficam sempre acesas, sem linha
    // própria, por isso nunca saem deste conjunto.
    @State private var activePartners: Set<String> = ["marriott", "hilton", "accor", "ihg", "hyatt", "melia", "blaxx"]

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

    // Cada hotel usa uma cor da legenda do globo (mesma paleta dos pontos
    // acesos em RotatingGlobe). Marriott→roxo e Accor→verde batem com a cor
    // do próprio ponto no globo.
    // `key` casa com o `group` dos destinos no RotatingGlobe — tocar na linha
    // acende/apaga os pontos daquela cor no globo.
    private let hotels: [(key: String, mono: String, name: String, sub: String, color: Color)] = [
        ("marriott", "M", "Marriott Bonvoy", "8.500+ hotéis · 139 países", Color(red: 0.608, green: 0.424, blue: 0.941)),
        ("hilton", "H", "Hilton Honors", "7.000+ hotéis · 122 países", Color(red: 0.310, green: 0.561, blue: 0.941)),
        ("accor", "A", "Accor ALL", "5.500+ hotéis · 110 países", Color(red: 0.310, green: 0.788, blue: 0.416)),
        ("ihg", "I", "IHG One Rewards", "6.000+ hotéis · 100 países", Color(red: 0.247, green: 0.776, blue: 0.847)),
        ("hyatt", "Y", "World of Hyatt", "1.300+ hotéis · 75 países", Color(red: 0.906, green: 0.698, blue: 0.290)),
        ("melia", "ML", "Meliá Rewards", "380+ hotéis · 40 países", Color(red: 0.878, green: 0.376, blue: 0.627)),
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
            RotatingGlobe(diameter: 360, activePartners: activePartners)
                .padding(.vertical, 4)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Text("Hotéis que aceitam pontos").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("rede em expansão").font(.system(size: 10, weight: .bold))
                        .lineLimit(1).fixedSize()
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(BlaxxColor.lime.opacity(0.16))).foregroundStyle(BlaxxColor.lime)
                }
                Text("Toque num parceiro para acender ou apagar seus pontos no globo.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4).padding(.bottom, 10)
                ForEach(hotels, id: \.key) { h in
                    let on = activePartners.contains(h.key)
                    HStack(spacing: 12) {
                        Text(h.mono).font(.system(size: 14, weight: .black)).foregroundStyle(BlaxxColor.black)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 12).fill(h.color))
                            .shadow(color: on ? h.color.opacity(0.55) : .clear, radius: on ? 8 : 0)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                .lineLimit(1).minimumScaleFactor(0.8)
                            Text(h.sub).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 5) {
                            Image(systemName: on ? "lightbulb.fill" : "lightbulb.slash")
                                .font(.system(size: 11, weight: .bold))
                            Text(on ? "Aceso" : "Apagado").font(.system(size: 12, weight: .bold))
                                .lineLimit(1).fixedSize()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(on ? BlaxxColor.lime : Color.white.opacity(0.12)))
                        .foregroundStyle(on ? BlaxxColor.black : Color.white.opacity(0.65))
                    }
                    .padding(.vertical, 10)
                    .opacity(on ? 1 : 0.55)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if on { activePartners.remove(h.key) } else { activePartners.insert(h.key) }
                        }
                    }
                    if h.key != hotels.last?.key { Divider().overlay(Color.white.opacity(0.1)) }
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
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(t.3).font(.system(size: 12)).foregroundStyle(t.4 ? Color(white: 0.8) : BlaxxColor.gray600)
                            .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(t.2).font(.system(size: 12, weight: .semibold)).foregroundStyle(t.4 ? BlaxxColor.lime : BlaxxColor.gray400)
                        .lineLimit(1).fixedSize()
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
    // Barra escura fixa (paridade com a web): sobre o hero escuro ela se funde,
    // e sobre as seções claras vira uma top-nav escura — padrão premium. O
    // wordmark vai tone .light (Bla branco + Xx neon) para ler no escuro.
    private var header: some View {
        HStack {
            BlaxxWordmark(size: 26, tone: .light)
            Spacer()
            Button("Entrar", action: onEnter)
                .buttonStyle(GhostButtonStyle(onDark: true))
            Button("Criar conta", action: onEnter)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(BlaxxColor.black.opacity(0.92))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)), alignment: .bottom)
    }

    // MARK: - Hero
    // Hero ESCURO em paridade com a landing web: sobre o preto institucional o
    // verde neon (#59FD27) salta. No fundo claro/creme o neon sumia (contraste
    // ~1:1), por isso os acentos usavam o verde escuro #5AB800 — que parecia
    // "apagado". Trocando o fundo para escuro, a marca volta ao verde oficial.
    private var hero: some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                Eyebrow(text: "Pontos · Pix · Vantagens", color: BlaxxColor.lime)
                (Text("Compre. Ganhe. ") + Text("Troque.").foregroundColor(BlaxxColor.lime) + Text(" Envie."))
                    .font(BlaxxFont.display(40, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A plataforma que transforma seus pontos em Pix na hora, milhas, diárias de hotel e salas VIP — com os melhores parceiros do Brasil e do mundo.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                HStack(spacing: 12) {
                    Button("Criar conta e ganhar 500 pts →", action: onEnter)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Já tenho conta · Entrar", action: onEnter)
                        .buttonStyle(GhostButtonStyle(onDark: true))
                }
                Text("★★★★★  Mais de 1 milhão de resgates realizados")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }

            walletMock
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 124)
        .padding(.horizontal, 24)
        .padding(.bottom, 64)
        .background(
            LinearGradient(colors: [BlaxxColor.black,
                                    Color(red: 0.024, green: 0.031, blue: 0.039)],
                           startPoint: .top, endPoint: .bottom)
        )
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
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
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

/// Globo ortográfico que gira continuamente — mesma função do globo d3 da
/// landing web, porém nativo (Canvas + TimelineView, sem WebView/CDN).
/// Destinos premium brilham e somem ao passar para o hemisfério de trás.
private struct RotatingGlobe: View {
    struct Dest { let lat: Double; let lon: Double; let color: Color; let group: String }

    var diameter: CGFloat = 360
    /// Graus por segundo da rotação (a web gira ~9,6°/s).
    var speed: Double = 10
    /// Parceiros acesos; só destinos cujo `group` está aqui são desenhados.
    var activePartners: Set<String> = []

    // Interação de arraste (mesma sensação do globo d3 da web). Mutar @State
    // durante o render do body é proibido, então guardamos uma longitude-âncora
    // (baseLon) + o instante (anchor) em que a rotação retomou: a longitude
    // efetiva é baseLon + tempo decorrido × speed. baseLon/anchor só mudam no
    // início/fim do arraste, nunca durante o desenho.
    @State private var baseLon: Double = 20
    @State private var tilt: Double = 16
    @State private var spinning = true
    @State private var anchor = Date()
    @State private var dragStartLon: Double? = nil
    @State private var dragStartTilt: Double = 16
    @State private var dragGen = 0

    static let destinations: [Dest] = {
        let lime   = BlaxxColor.lime
        let gold   = Color(red: 0.906, green: 0.698, blue: 0.290)
        let pink   = Color(red: 0.878, green: 0.376, blue: 0.627)
        let blue   = Color(red: 0.310, green: 0.561, blue: 0.941)
        let green  = Color(red: 0.310, green: 0.788, blue: 0.416)
        let purple = Color(red: 0.608, green: 0.424, blue: 0.941)
        let cyan   = Color(red: 0.247, green: 0.776, blue: 0.847)
        return [
            Dest(lat: -23.5, lon: -46.6, color: lime,    group: "blaxx"),    Dest(lat: -22.9, lon: -43.2, color: gold,    group: "hyatt"),
            Dest(lat: -34.6, lon: -58.4, color: pink,    group: "melia"),    Dest(lat: -33.4, lon: -70.6, color: pink,    group: "melia"),
            Dest(lat: -12.0, lon: -77.0, color: blue,    group: "hilton"),   Dest(lat:   4.7, lon: -74.0, color: blue,    group: "hilton"),
            Dest(lat:  25.7, lon: -80.2, color: gold,    group: "hyatt"),    Dest(lat:  40.7, lon: -74.0, color: purple,  group: "marriott"),
            Dest(lat:  34.0, lon: -118.2, color: purple, group: "marriott"), Dest(lat:  21.1, lon: -86.8, color: green,   group: "accor"),
            Dest(lat:  38.7, lon:  -9.1, color: lime,    group: "blaxx"),    Dest(lat:  40.4, lon:  -3.7, color: pink,    group: "melia"),
            Dest(lat:  48.8, lon:   2.3, color: green,   group: "accor"),    Dest(lat:  51.5, lon:  -0.1, color: green,   group: "accor"),
            Dest(lat:  50.0, lon:   8.5, color: cyan,    group: "ihg"),      Dest(lat:  41.0, lon:  28.9, color: cyan,    group: "ihg"),
            Dest(lat:  25.2, lon:  55.3, color: green,   group: "accor"),    Dest(lat:  25.3, lon:  51.5, color: cyan,    group: "ihg"),
            Dest(lat:  13.7, lon: 100.5, color: green,   group: "accor"),    Dest(lat:   1.3, lon: 103.8, color: green,   group: "accor"),
            Dest(lat:  22.3, lon: 114.2, color: cyan,    group: "ihg"),      Dest(lat:  35.6, lon: 139.7, color: purple,  group: "marriott"),
            Dest(lat:  31.2, lon: 121.5, color: purple,  group: "marriott"), Dest(lat: -33.8, lon: 151.2, color: green,   group: "accor"),
        ]
    }()

    /// Longitude exibida agora: âncora + tempo girando × velocidade.
    private func effectiveLon(_ now: Date) -> Double {
        baseLon + (spinning ? now.timeIntervalSince(anchor) * speed : 0)
    }

    var body: some View {
        // Globo responsivo: ocupa até `diameter`, encolhe para caber em telas
        // estreitas (nunca extrapola a largura do card).
        GeometryReader { geo in
            let d = min(diameter, geo.size.width)
            TimelineView(.animation) { timeline in
                Canvas { ctx, size in
                    Self.render(ctx, size: size,
                                spinDeg: effectiveLon(timeline.date),
                                tiltDeg: tilt,
                                active: activePartners)
                }
            }
            .frame(width: d, height: d)
            // O gesto fica no contêiner estável (não no Canvas, recriado a ~60 fps,
            // que cortaria um arraste em andamento).
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: diameter)
        .accessibilityLabel("Globo com destinos onde seus pontos podem ser usados. Arraste para girar.")
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                if dragStartLon == nil {            // começo do arraste: congela a rotação
                    dragStartLon = effectiveLon(Date())
                    dragStartTilt = tilt
                    baseLon = dragStartLon!
                    spinning = false
                    dragGen &+= 1
                }
                baseLon = (dragStartLon ?? baseLon) + v.translation.width * 0.5
                tilt = max(-80, min(80, dragStartTilt - v.translation.height * 0.5))
            }
            .onEnded { _ in
                guard dragStartLon != nil else { return }   // ignora toque sem arraste real
                dragStartLon = nil
                let gen = dragGen
                // Retoma o giro 2,5 s depois — salvo se um novo arraste começar antes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    if dragGen == gen && dragStartLon == nil {
                        anchor = Date()
                        spinning = true
                    }
                }
            }
    }

    private static func render(_ ctx: GraphicsContext, size: CGSize, spinDeg: Double, tiltDeg: Double, active: Set<String>) {
        let cx = size.width / 2, cy = size.height / 2
        let R = min(size.width, size.height) * 0.45
        let phi0 = tiltDeg * .pi / 180
        let lam0 = spinDeg * .pi / 180
        let sinP0 = sin(phi0), cosP0 = cos(phi0)

        // Projeção ortográfica; retorna nil quando o ponto está atrás do globo.
        func project(_ latDeg: Double, _ lonDeg: Double) -> (CGPoint, Double)? {
            let la = latDeg * .pi / 180, lo = lonDeg * .pi / 180
            let dl = lo - lam0
            let cosc = sinP0 * sin(la) + cosP0 * cos(la) * cos(dl)
            if cosc < 0 { return nil }
            let x = cos(la) * sin(dl)
            let y = cosP0 * sin(la) - sinP0 * cos(la) * cos(dl)
            return (CGPoint(x: cx + R * x, y: cy - R * y), cosc)
        }
        func strokeArc(_ samples: [(Double, Double)], _ color: Color, _ w: CGFloat) {
            var path = Path(); var pen = false
            for (la, lo) in samples {
                if let (p, _) = project(la, lo) {
                    if pen { path.addLine(to: p) } else { path.move(to: p); pen = true }
                } else { pen = false }
            }
            ctx.stroke(path, with: .color(color), lineWidth: w)
        }

        let sphereRect = CGRect(x: cx - R, y: cy - R, width: 2 * R, height: 2 * R)

        // 1) Atmosfera (halo lime).
        let atmR = R * 1.30
        ctx.fill(Path(ellipseIn: CGRect(x: cx - atmR, y: cy - atmR, width: 2 * atmR, height: 2 * atmR)),
                 with: .radialGradient(Gradient(colors: [BlaxxColor.lime.opacity(0.12), .clear]),
                                       center: CGPoint(x: cx, y: cy), startRadius: R * 0.92, endRadius: atmR))

        // 2) Esfera (gradiente escuro com realce no topo-esquerda).
        ctx.fill(Path(ellipseIn: sphereRect), with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.102, green: 0.133, blue: 0.188), location: 0),
                .init(color: Color(red: 0.055, green: 0.075, blue: 0.110), location: 0.65),
                .init(color: Color(red: 0.027, green: 0.027, blue: 0.035), location: 1),
            ]),
            center: CGPoint(x: cx - R * 0.35, y: cy - R * 0.35), startRadius: R * 0.1, endRadius: R))

        // 3) Graticule (meridianos + paralelos), bem sutil.
        for lon in stride(from: -180.0, to: 180.0, by: 30) {
            strokeArc(stride(from: -85.0, through: 85.0, by: 4).map { ($0, lon) },
                      .white.opacity(0.06), 0.6)
        }
        for lat in stride(from: -60.0, through: 60.0, by: 30) {
            strokeArc(stride(from: -180.0, through: 180.0, by: 4).map { (lat, $0) },
                      .white.opacity(lat == 0 ? 0.09 : 0.05), lat == 0 ? 0.7 : 0.6)
        }

        // 3.5) Fronteiras verde BlaXx (#59FD27) dos países (costa + limites), bem definidas.
        // Brilho difuso por baixo + traço nítido por cima. project() devolve nil
        // no hemisfério de trás, então a caneta levanta e o contorno some na borda.
        var borderPath = Path()
        for arc in WorldBorders.arcs {
            var pen = false
            for (la, lo) in arc {
                if let (p, _) = project(la, lo) {
                    if pen { borderPath.addLine(to: p) } else { borderPath.move(to: p); pen = true }
                } else { pen = false }
            }
        }
        ctx.stroke(borderPath, with: .color(BlaxxColor.lime.opacity(0.20)), lineWidth: 2.4)
        ctx.stroke(borderPath, with: .color(BlaxxColor.lime), lineWidth: 0.9)

        // 4) Limbo (anel lime).
        ctx.stroke(Path(ellipseIn: sphereRect), with: .color(BlaxxColor.lime.opacity(0.28)), lineWidth: 1)

        // 5) Destinos: brilho + ponto, opacidade pela profundidade (z = cosc).
        //    Só os parceiros acesos aparecem (espelha os chips da legenda na web).
        for d in destinations {
            guard active.contains(d.group) else { continue }
            guard let (p, z) = project(d.lat, d.lon) else { continue }
            let glowR = CGFloat(7 + 8 * z)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - glowR, y: p.y - glowR, width: 2 * glowR, height: 2 * glowR)),
                     with: .radialGradient(Gradient(colors: [d.color.opacity(0.22 + 0.5 * z), .clear]),
                                           center: p, startRadius: 0, endRadius: glowR))
            let dotR = CGFloat(1.6 + 1.4 * z)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR, width: 2 * dotR, height: 2 * dotR)),
                     with: .color(d.color.opacity(0.65 + 0.35 * z)))
        }
    }
}

#Preview("Home") {
    HomeView(onEnter: {})
}
