//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI
import CachedAsyncImage

struct AvatarView: View {

    let url: URL?
    let showAvatar: Bool
    let avatarSize: CGFloat

    var body: some View {
        if showAvatar {
            CachedAsyncImage(url: url, urlCache: .imageCache) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.gray)
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
        }
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        AvatarView(
            url: URL(string: "https://placeimg.com/640/480/sepia"),
            showAvatar: true,
            avatarSize: 32
        )
    }
}