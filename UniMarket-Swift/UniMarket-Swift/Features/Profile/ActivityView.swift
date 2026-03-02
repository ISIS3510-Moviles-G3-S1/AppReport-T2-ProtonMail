//
//  ActivityView.swift
//  UniMarket-Swift
//
//  Created by Mariana Pineda on 1/03/26.
//

import SwiftUI

struct ActivityView: View {
    @StateObject private var vm = ActivityViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                HStack {
                    Text("Profile")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal)

                Picker("", selection: $vm.selectedTab) {
                    ForEach(ActivityViewModel.Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch vm.selectedTab {
                    case .activity:
                        activitySection
                    case .listings:
                        listingsSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 90) // espacio tab bar
            }
            .padding(.top, 10)
        }
        .sheet(item: $vm.editingListing) { listing in
            EditListingView(
                listing: listing,
                onCancel: { vm.editingListing = nil },
                onSave: { vm.saveEdits($0) }
            )
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(vm.activity, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.green.opacity(0.35))
                        .frame(width: 10, height: 10)
                        .padding(.top, 6)

                    Text(item)
                        .font(.subheadline)

                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.10))
                .cornerRadius(16)
            }
        }
    }

    private var listingsSection: some View {
        VStack(spacing: 14) {
            ForEach(vm.listings) { listing in
                ListingCard(
                    listing: listing,
                    onEdit: { vm.openEdit(listing) },
                    onDelete: { vm.deleteListing(listing) }
                )
            }
        }
    }
}
