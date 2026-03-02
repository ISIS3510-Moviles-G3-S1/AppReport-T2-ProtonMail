//
//  ProfileView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Profile")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                ProfileHeaderCard(profile: vm.profile)
                    .padding(.horizontal)

                Divider().padding(.horizontal)

                EcoSaysCard(message: vm.ecoMessage)
                    .padding(.horizontal)

                SustainabilityProgressCard(profile: vm.profile)
                    .padding(.horizontal)

            }
            .padding(.top, 10)
        }
    }
}
